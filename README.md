## Introduction

Contracts for "LensMaxi", a project which allows access to gated publications only if a user subscribes to the creator using Superfluid Protocol token streams. The content is encrypted and decrypted using Lit Protocol and the publications themselves can be Lens Protocol publications.

## How to Use The Contracts

A creator, defined as the person who publishes content, has to create a set of contracts using `initCreatorSet`. The creator has to give the following arguments:

- `address _paymentToken`: The super token accepted as payment by the creator.
- `int96 _paymentFlowrate`: The flow rate (amount of tokens to be received per month) desired by the creator.
- `string memory _stName`: The social token's name.
- `string memory _stSymbol`: The social token's symbol.
- `uint256 _initSupply`: The initial supply of social token.

Note that the the creator can have only 1 set of contracts. This is a deliberate decision to have all the data in the factory contract. We can remove this if a requirement arises where multiple sets are require.

As a subscriber, just open a Superfluid token stream (equivalent or greater than the `_paymentFlowrate`) to the `StreamManager` contract of a creator's set whose address you can get from `creatorSet` mapping in the `SuperLensFactory`. Lit Protocol should give you access to any Lens Protocol gated publication.
