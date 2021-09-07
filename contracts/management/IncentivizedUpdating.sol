//SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@pythia-oracle/pythia-library/contracts/interfaces/IUpdateByToken.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract IncentivizedUpdating is AccessControl, ReentrancyGuard {
    struct Incentive {
        bool enabled;
        IERC20 compensationToken;
        uint256 amountPerLitreGas;
    }

    /*
     * Roles
     */

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    bytes32 public constant INCENTIVE_MAINTAINER = keccak256("INCENTIVE_MAINTAINER");

    bytes32 public constant WHITELIST_MAINTAINER = keccak256("WHITELIST_MAINTAINER");

    /*
     * Whitelists
     */

    mapping(IUpdateByToken => bool) public whitelistedUpdateables;
    mapping(IERC20 => bool) public whitelistedTokens;

    /*
     * Reward token management
     */

    mapping(IERC20 => uint256) public virtualBalances;
    mapping(IERC20 => uint256) public totalPayable;

    mapping(IERC20 => mapping(address => uint256)) public accruedIncentives;

    mapping(IERC20 => bool) public isCompensationToken;

    /*
     * Incentives
     */

    mapping(IERC20 => Incentive[]) public incentivesForToken;

    /*
     * Events - update handling
     */

    event UpdateErrorWithReason(IERC20 indexed token, string reason);

    event UpdateError(IERC20 indexed token, bytes err);

    event UpdateableUpdated(IUpdateByToken indexed updateable, IERC20 indexed token, address indexed updater);

    /*
     * Events - incentives
     */

    event AddedIncentive(IERC20 indexed token, IERC20 indexed compensationToken);

    event RemovedIncentive(IERC20 indexed token, IERC20 indexed compensationToken);

    event UpdatedIncentive(IERC20 indexed token, IERC20 indexed compensationToken, uint256 amountPerLitreGas);

    event ToggledIncentive(IERC20 indexed token, IERC20 indexed compensationToken, bool enabled);

    event IncentiveDriedUp(IERC20 indexed token, IERC20 indexed compensationToken);

    event DistributedIncentive(
        IERC20 indexed token,
        IERC20 indexed compensationToken,
        address indexed recipient,
        uint256 amount
    );

    event ClaimedIncentive(IERC20 indexed compensationToken, address indexed recipient, uint256 amount);

    /*
     * Events - whitelists
     */

    event UpdatedWhitelistedUpdateable(IUpdateByToken indexed updateable, bool whitelisted);

    event UpdatedWhitelistedToken(IERC20 indexed token, bool whitelisted);

    /*
     * External functions - WHITELIST_MAINTAINER - whitelist
     */

    function whitelistUpdateable(IUpdateByToken updateable, bool whitelist) external onlyRole(WHITELIST_MAINTAINER) {
        if (whitelistedUpdateables[updateable] != whitelist) {
            whitelistedUpdateables[updateable] = whitelist;

            emit UpdatedWhitelistedUpdateable(updateable, whitelist);
        }
    }

    function whitelistToken(IERC20 token, bool whitelist) external onlyRole(WHITELIST_MAINTAINER) {
        if (whitelistedTokens[token] != whitelist) {
            whitelistedTokens[token] = whitelist;

            emit UpdatedWhitelistedToken(token, whitelist);
        }
    }

    /*
     * External functions - ADMIN_ROLE - token holdings
     */

    function transferToken(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        if (isCompensationToken[token]) {
            // The token is a compensation token so we must ensure we aren't transferring more than we owe

            // Ensure the virtual balance is up-to-date
            _pokeVirtualBalance(token);

            require(amount >= virtualBalances[token], "IncentivizedUpdating: INSUFFICIENT_FUNDS");

            // Subtract the amount from the virtual balance
            virtualBalances[token] -= amount;
        }

        token.approve(address(this), amount);
        token.transfer(recipient, amount);
    }

    /*
     * External functions - INCENTIVE_MAINTAINER - incentives
     */

    function addIncentiveForToken(
        IERC20 token,
        IERC20 compensationToken,
        uint256 amountPerLitreGas
    ) external onlyRole(INCENTIVE_MAINTAINER) {
        require(!_incentiveExists(token, compensationToken), "IncentivizedUpdating: INCENTIVE_ALREADY_EXISTS");
        require(amountPerLitreGas > 0, "IncentivizedUpdating: INVALID_INPUT");

        Incentive memory incentive;

        incentive.enabled = true;
        incentive.compensationToken = compensationToken;
        incentive.amountPerLitreGas = amountPerLitreGas;

        incentivesForToken[token].push(incentive);

        // Record the compensation token as being a compensation token
        isCompensationToken[compensationToken] = true;

        // Ensure virtual balance is up-to-date
        _pokeVirtualBalance(compensationToken);

        emit AddedIncentive(token, compensationToken);
        emit UpdatedIncentive(token, compensationToken, amountPerLitreGas);
        emit ToggledIncentive(token, compensationToken, true);
    }

    function updateIncentiveForToken(
        IERC20 token,
        IERC20 compensationToken,
        uint256 amountPerLitreGas
    ) external onlyRole(INCENTIVE_MAINTAINER) {
        require(_incentiveExists(token, compensationToken), "IncentivizedUpdating: INCENTIVE_DOESNT_EXIST");

        Incentive storage incentive = _getIncentiveForToken(token, compensationToken);

        if (amountPerLitreGas != incentive.amountPerLitreGas) {
            incentive.amountPerLitreGas = amountPerLitreGas;

            emit UpdatedIncentive(token, compensationToken, amountPerLitreGas);
        }
    }

    function toggleIncentiveForToken(
        IERC20 token,
        IERC20 compensationToken,
        bool enabled
    ) external onlyRole(INCENTIVE_MAINTAINER) {
        require(_incentiveExists(token, compensationToken), "IncentivizedUpdating: INCENTIVE_DOESNT_EXIST");

        if (enabled) {
            // Ensure virtual balance is up-to-date
            _pokeVirtualBalance(compensationToken);

            // Only enable if we have a virtual balance
            require(virtualBalances[compensationToken] > 0, "IncentivizedUpdating: BALANCE_EMPTY");
        }

        Incentive storage incentive = _getIncentiveForToken(token, compensationToken);

        incentive.enabled = enabled;

        emit ToggledIncentive(token, compensationToken, enabled);
    }

    function removeIncentiveForToken(IERC20 token, IERC20 compensationToken) external onlyRole(INCENTIVE_MAINTAINER) {
        require(_incentiveExists(token, compensationToken), "IncentivizedUpdating: INCENTIVE_DOESNT_EXIST");

        // Copy current incentives into memory
        Incentive[] memory currentIncentives = incentivesForToken[token];

        // Clear the current incentives
        incentivesForToken[token] = new Incentive[](0);

        for (uint256 i = 0; i < currentIncentives.length; ++i) {
            if (address(currentIncentives[i].compensationToken) != address(compensationToken)) {
                // Add back this incentive as it's not the one we are removing
                incentivesForToken[token].push(currentIncentives[i]);
            }
        }

        // Not needed, but we emit for consistency
        emit ToggledIncentive(token, compensationToken, false);

        emit RemovedIncentive(token, compensationToken);
    }

    /*
     * External functions - bookkeeping
     */

    function pokeVirtualBalance(IERC20 compensationToken) external {
        // We only want to store the balances of valid compensation tokens
        if (isCompensationToken[compensationToken]) _pokeVirtualBalance(compensationToken);
    }

    /*
     * External functions - incentives
     */

    function claimIncentive(IERC20 compensationToken, address recipient) external nonReentrant {
        uint256 claimAmount = accruedIncentives[compensationToken][recipient];
        require(claimAmount > 0, "IncentivizedUpdating: NOTHING_TO_CLAIM");

        // Always update bookkeeping records before we transfer for security
        accruedIncentives[compensationToken][recipient] = 0;
        totalPayable[compensationToken] -= claimAmount;

        compensationToken.approve(address(this), claimAmount);
        compensationToken.transfer(recipient, claimAmount);

        emit ClaimedIncentive(compensationToken, recipient, claimAmount);
    }

    function getAvailableIncentives(IERC20 token) external view returns (Incentive[] memory) {
        Incentive[] storage incentives = incentivesForToken[token];
        uint256 incentivesLen = incentives.length;

        uint256 available;

        for (uint256 i = 0; i < incentivesLen; ++i) {
            if (virtualBalances[incentives[i].compensationToken] > 0) ++available;
        }

        Incentive[] memory availableIncentives = new Incentive[](available);

        uint256 j;

        for (uint256 i = 0; i < incentivesLen; ++i) {
            if (virtualBalances[incentives[i].compensationToken] > 0) availableIncentives[j++] = incentives[i];
        }

        return availableIncentives;
    }

    /*
     * External functions - update calls
     */

    function update(IUpdateByToken updateable, IERC20 token) external {
        require(whitelistedUpdateables[updateable], "IncentivizedUpdating: UPDATEABLE_NOT_ELIGIBLE");
        require(whitelistedTokens[token], "IncentivizedUpdating: TOKEN_NOT_ELIGIBLE");

        uint256 gasUsed = _update(updateable, token, msg.sender);
        if (gasUsed > 0) _distributeIncentivesForToken(token, gasUsed, msg.sender);
    }

    function update(IUpdateByToken updateable, IERC20[] memory tokens) external {
        require(whitelistedUpdateables[updateable], "IncentivizedUpdating: UPDATEABLE_NOT_ELIGIBLE");

        uint256 gasUsed;

        for (uint256 i = 0; i < tokens.length; ++i) {
            require(whitelistedTokens[tokens[i]], "IncentivizedUpdating: TOKEN_NOT_ELIGIBLE");

            gasUsed = _update(updateable, tokens[i], msg.sender);
            if (gasUsed > 0) _distributeIncentivesForToken(tokens[i], gasUsed, msg.sender);
        }
    }

    function update(IUpdateByToken[] memory updateables, IERC20 token) external {
        require(whitelistedTokens[token], "IncentivizedUpdating: TOKEN_NOT_ELIGIBLE");

        uint256 gasUsed;

        for (uint256 i = 0; i < updateables.length; ++i) {
            require(whitelistedUpdateables[updateables[i]], "IncentivizedUpdating: UPDATEABLE_NOT_ELIGIBLE");

            gasUsed += _update(updateables[i], token, msg.sender);
        }

        if (gasUsed > 0) _distributeIncentivesForToken(token, gasUsed, msg.sender);
    }

    function update(IUpdateByToken[] memory updateables, IERC20[] memory tokens) external {
        require(updateables.length == tokens.length, "IncentivizedUpdating: INVALID_INPUT");

        uint256 gasUsed;

        for (uint256 i = 0; i < updateables.length; ++i) {
            require(whitelistedUpdateables[updateables[i]], "IncentivizedUpdating: UPDATEABLE_NOT_ELIGIBLE");
            require(whitelistedTokens[tokens[i]], "IncentivizedUpdating: TOKEN_NOT_ELIGIBLE");

            gasUsed = _update(updateables[i], tokens[i], msg.sender);
            if (gasUsed > 0) _distributeIncentivesForToken(tokens[i], gasUsed, msg.sender);
        }
    }

    /*
     * Internal functions
     */

    function _update(
        IUpdateByToken updateable,
        IERC20 token,
        address updater
    ) internal returns (uint256 gasUsed) {
        uint256 gasStart = gasleft();

        try IUpdateByToken(updateable).update(address(token)) returns (bool updated) {
            if (updated) {
                gasUsed = gasleft() - gasStart;

                emit UpdateableUpdated(updateable, token, updater);
            }
        } catch Error(string memory reason) {
            emit UpdateErrorWithReason(token, reason);
        } catch (bytes memory err) {
            emit UpdateError(token, err);
        }
    }

    function _distributeIncentivesForToken(
        IERC20 token,
        uint256 gasUsed,
        address recipient
    ) internal {
        // Add 500 to round to the nearest 1K gas used
        uint256 litreGasUsed = (gasUsed + 500) / 1000;

        // Don't distribute anything if we used less than a litre of gas
        if (litreGasUsed == 0) return;

        Incentive[] storage tokenIncentives = incentivesForToken[token];
        uint256 tokenIncentivesLen = tokenIncentives.length;

        for (uint256 i = 0; i < tokenIncentivesLen; ++i) {
            Incentive storage incentive = tokenIncentives[i];

            if (incentive.enabled) {
                uint256 amount = litreGasUsed * incentive.amountPerLitreGas;
                uint256 amountLeft = virtualBalances[incentive.compensationToken];

                if (amount > amountLeft) {
                    // Only distribute as much as we have left
                    amount = amountLeft;

                    emit IncentiveDriedUp(token, incentive.compensationToken);
                }

                if (amount > 0) {
                    // Distribute the incentive
                    accruedIncentives[incentive.compensationToken][recipient] += amount;

                    // Book keeping
                    totalPayable[incentive.compensationToken] += amount;
                    virtualBalances[incentive.compensationToken] -= amount;

                    emit DistributedIncentive(token, incentive.compensationToken, recipient, amount);
                }
            }
        }
    }

    function _incentiveExists(IERC20 token, IERC20 compensationToken) internal view returns (bool) {
        Incentive[] storage tokenIncentives = incentivesForToken[token];
        uint256 tokenIncentivesLen = tokenIncentives.length;

        for (uint256 i = 0; i < tokenIncentivesLen; ++i) {
            if (address(tokenIncentives[i].compensationToken) == address(compensationToken)) return true;
        }

        return false;
    }

    function _pokeVirtualBalance(IERC20 compensationToken) internal {
        virtualBalances[compensationToken] =
            compensationToken.balanceOf(address(this)) -
            totalPayable[compensationToken];
    }

    function _getIncentiveForToken(IERC20 token, IERC20 compensationToken) internal view returns (Incentive storage) {
        Incentive[] storage tokenIncentives = incentivesForToken[token];
        uint256 tokenIncentivesLen = tokenIncentives.length;

        for (uint256 i = 0; i < tokenIncentivesLen; ++i) {
            if (address(tokenIncentives[i].compensationToken) == address(compensationToken)) return tokenIncentives[i];
        }

        revert("IncentivizedUpdating: INCENTIVE_DOESNT_EXIST");
    }
}
