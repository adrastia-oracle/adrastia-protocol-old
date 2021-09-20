# Pythia Protocol Governance

## Overview
Governance is broken into roles, each with a unique set of responsibilities. These roles can be fulfilled by single entities, governance boards, or even other DAOs.

## Roles and responsibilities

### Super role
Responsibilities:
- Updating smart contracts
- Protecting overall protocol health

### Admin role
Responsibilities:
- General maintenance of the protocol

### Whitelist maintainer role
- Managing the list of assets supported by our official oracles
- Managing the list of updateables (i.e. oracles) that are eligible for incentives

### Incentive maintainer role
- Managing protocol incentives

## Governance boards
Governance boards are used to fulfill roles in a decentralized manner.

### Super board
Configuration:
- Voting delay: 1 week
- Voting period: 3 days
- Execution delay: 3 days
- Eligible voters: all token holders
- Eligible propoers: min. 5% voting power
- Quorum: 10% voting power
- Majority: 2/3

Roles: all roles

### Admin board
Configuration:
- Voting delay: 3 days
- Voting period: 2 days
- Execution delay: 1 day
- Eligible voters: all token holders
- Eligible propoers: min. 2% voting power
- Quorum: 5% voting power
- Majority: 1/2

Roles:
- Admin
- Whitelist maintainer
- Incentive maintainer

### Incentives board
Configuration:
- Voting delay: 2 days
- Voting period: 2 days
- Execution delay: none
- Eligible voters: all token holders
- Eligible propoers: min. 2% voting power
- Quorum: 5% voting power
- Majority: 1/2
Roles:
- Incentive maintainer
