# Test Plan for Staking contracts

## [StakeHolder.sol](../../contracts/staking/StakeHolder.sol)

Initialize testing (in [StakeHolderInit.t.sol](../../contracts/staking/StakeHolderInit.t.sol)):

| Test name                       | Description                                                | Happy Case | Implemented |
|---------------------------------|------------------------------------------------------------|------------|-------------|
| testGetVersion                  | Check version number.                                      | Yes        | No          |
| testStakersInit                 | Check initial staker's array length is zero.               | Yes        | No          |
| testAdmins                      | Check that role and upgrade admin have been set correctly. | Yes        | No          |


Configuration tests (in [StakeHolderConfig.t.sol](../../contracts/staking/StakeHolderConfig.t.sol))::

| Test name                       | Description                                                | Happy Case | Implemented |
|---------------------------------|------------------------------------------------------------|------------|-------------|
| testUpgradeToV1                 | Check upgrade process.                                     | Yes        | No          |
| testUpgradeToV0                 | Check upgrade to V0 fails.                                 | No         | No          |
| testDowngradeV1ToV0             | Check downgrade from V1 to V0 fails.                       | No         | No          |
| testUpgradeAuthFail             | Try upgrade from account that doesn't have upgrade role.   | No         | No          |
| testAddRevokeRenounceRoleAdmin  | Check adding, removing, and renouncing role admins.        | Yes        | No          |
| testAddRevokeRenounceUpgradeAdmin | Check adding, removing, and renouncing upgrade admins.   | Yes        | No          |
| testRenounceLastRoleAdmin       | Check that attempting to renounce last role admin fails.   | No         | No          |
| testRevokeLastRoleAdmin         | Check that attempting to revoke last role admin fails.     | No         | No          |
| testRoleAdminAuthFail           | Attempt to add an upgrade admin from a non-role admin.     | No         | No          |


Operational tests (in [StakeHolderOperational.t.sol](../../contracts/staking/StakeHolderOperational.t.sol))::

| Test name                      | Description                                                 | Happy Case | Implemented |
|--------------------------------|-------------------------------------------------------------|------------|-------------|
| testStake                      | Stake some value.                                           | Yes        | No          |
| testStakeTwice                 | Stake some value and then some more value.                  | Yes        | No          |
| testStakeZeroValue             | Stake with msg.value = 0.                                   | No         | No          |
| testMultipleStakers            | Check multiple entities staking works.                      | Yes        | No          |
| testUnstake                    | Check that an account can unstake all their value.          | Yes        | No          |
| testUnstakeTooMuch             | Attempt to unstake greater than balance.                    | No         | No          |
| testUnstakePartial             | Check that an account can unstake part of their value.      | Yes        | No          |
| testUnstakeMultiple            | Unstake in multiple parts.                                  | Yes        | No          |
| testUnstakeReentrantAttack     | Attempt a reentrancy attack on unstaking.                   | No         | No          |
| testRestaking                  | Stake, unstake, restake.                                    | Yes        | No          |
| testGetStakers                 | Check getStakers in various scenarios.                      | Yes        | No          |
| testGetStakersOutOfRange       | Check getStakers for out of range request.                  | No         | No          |
| testDistributeRewardsOne       | Distribute rewards to one account.                          | Yes        | No          |
| testDistributeRewardsMultiple  | Distribute rewards to multiple accounts.                    | Yes        | No          |
| testDistributeZeroReward       | Fail when distributing zero reward.                         | No         | No          |
| testDistributeMismatch         | Fail if the total to distribute does not equal msg.value.   | No         | No          |
| testDistributeToEmptyAccount   | Stake, unstake, distribute rewards.                         | Yes        | No          |
| testDistributeToUnusedAccount  | Attempt to distribute rewards to an account that has never staked. | No  | No          |

