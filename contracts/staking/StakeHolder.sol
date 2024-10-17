// Copyright (c) Immutable Pty Ltd 2018 - 2024
// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable-4.9.3/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from
    "openzeppelin-contracts-upgradeable-4.9.3/access/AccessControlEnumerableUpgradeable.sol";

/**
 * @title StakeHolder: allows anyone to stake any amount of native IMX and to then remove all or part of that stake.
 * @dev The StakeHolder contract is designed to be upgradeable.
 */
contract StakeHolder is AccessControlEnumerableUpgradeable, UUPSUpgradeable {
    /// @notice Error: Attempting to stake with zero value.
    error MustStakeMoreThanZero();

    /// @notice Error: Attempting to distribute zero value.
    error MustDistributeMoreThanZero();

    /// @notice Error: Attempting to unstake amount greater than the balance.
    error UnstakeAmountExceedsBalance(uint256 _amountToUnstake, uint256 _currentStake);

    /// @notice Error: The length of the receipients and the amounts array did not match.
    error RecipientsAmountsMismatch(uint256 _receipientsLength, uint256 _amountsLength);

    /// @notice Error: The sum of all amounts to distribute did not equal msg.value of the distribute transaction.
    error DistributionAmountsDoNotMatchTotal(uint256 _msgValue, uint256 _calculatedTotalDistribution);

    /// @notice Event when an amount has been staked or when an amount is distributed to an account.
    event StakeAdded(address _staker, uint256 _amountAdded, uint256 _newBalance);

    /// @notice Event when an amount has been unstaked.
    event StakeRemoved(address _staker, uint256 _amountRemoved, uint256 _newBalance);

    /// @notice Event summarising a distribution. There will also be one StakeAdded event for each recipient.
    event Distributed(address _distributor, uint256 _totalDistribution, uint256 _numRecipients);

    /// @notice Only UPGRADE_ROLE can upgrade the contract
    bytes32 public constant UPGRADE_ROLE = bytes32("UPGRADE_ROLE");

    /// @notice The amount of value owned by each staker
    // solhint-disable-next-line private-vars-leading-underscore
    mapping(address staker => uint256 stake) private balances;

    /// @notice A list of all stakers who have ever staked.
    /// Note that it is possible that this list will contain duplicates if an account stakes,
    /// then fully unstakes, and then stakes again.
    /// Not reordering the list of stakers means that off-chain services could cache results,
    /// thus only needing to fetch new entries in the array.
    // solhint-disable-next-line private-vars-leading-underscore
    address[] private stakers;

    /**
     * @notice Initialises the upgradeable contract, setting up admin accounts.
     * @param _roleAdmin the address to grant `DEFAULT_ADMIN_ROLE` to
     * @param _upgradeAdmin the address to grant `UPGRADE_ROLE` to
     */
    function initialize(address _roleAdmin, address _upgradeAdmin) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _roleAdmin);
        _grantRole(UPGRADE_ROLE, _upgradeAdmin);
    }

    /**
     * @notice Allow any account to stake more value.
     * @dev The amount being staked is the value of msg.value.
     * @dev This function does not need re-entrancy guard as the add stake
     *  mechanism does not call out to any external function.
     */
    function stake() external payable {
        if (msg.value == 0) {
            revert MustStakeMoreThanZero();
        }
        addStake(msg.sender, msg.value);
    }

    /**
     * @notice Allow any account to remove some or all of their own stake.
     * @dev This function does not need re-entrancy guard as the state is updated
     *  prior to the call to the user's wallet.
     * @param _amountToUnstake Amount of stake to remove.
     */
    function unstake(uint256 _amountToUnstake) external {
        uint256 currentStake = balances[msg.sender];
        if (currentStake < _amountToUnstake) {
            revert UnstakeAmountExceedsBalance(_amountToUnstake, currentStake);
        }
        uint256 newBalance = currentStake - _amountToUnstake;
        balances[msg.sender] = newBalance;

        payable(msg.sender).transfer(_amountToUnstake);

        emit StakeRemoved(msg.sender, _amountToUnstake, newBalance);
    }

    /**
     * @notice Any account can distribute tokens to any set of accounts.
     * @dev The total amount to distribute must match msg.value.
     *  This function does not need re-entrancy guard as the distribution mechanism 
     *  does not call out to another contract.
     * @param _recipients An array of recipients to distribute value to.
     * @param _amounts An array of amounts to be distributed to each recipient.
     */
    function distributeRewards(address[] calldata _recipients, uint256[] calldata _amounts)
        external
        payable
    {
        // Initial validity checks
        if (msg.value == 0) {
            revert MustDistributeMoreThanZero();
        }
        uint256 len = _recipients.length;
        if (len != _amounts.length) {
            revert RecipientsAmountsMismatch(len, _amounts.length);
        }

        // Distribute the value.
        uint256 total = 0;
        for (uint256 i = 0; i < len; i++) {
            uint256 amount = _amounts[i];
            addStake(_recipients[i], amount);
            total += amount;
        }

        // Check that the total distributed matches the msg.value.
        if (total != msg.value) {
            revert DistributionAmountsDoNotMatchTotal(msg.value, total);
        }
        emit Distributed(msg.sender, msg.value, len);
    }

    /**
     * @notice Get the balance of an account.
     * @param _account The account to return the balance for.
     * @return _balance The balance of the account.
     */
    function getBalance(address _account) external view returns (uint256 _balance) {
        return balances[_account];
    }

    /**
     * @notice Get the length of the stakers array.
     * @dev This will be greater than or equal to the number of staker accounts that have
     *  ever existed. Some of the accounts might have a zero balance, having staked and then
     *  unstaked. Some accounts could be in the array two or more times, having staked, unstaked,
     *  and then staked again. Another scenario could be an account staking, unstaking, and then having
     *  a distribution paid.
     * @return _len The length of the stakers array.
     */
    function getNumStakers() external view returns (uint256 _len) {
        return stakers.length;
    }

    /**
     * @notice Get the staker accounts from the stakers array.
     * @dev Given the stakers list could grow arbitrarily long. To prevent out of memory or out of
     *  gas situations due to attempting to return a very large array, this function call specifies
     *  the start offset and number of accounts to be return.
     *  NOTE: This code will cause a panic if the start offset + number to return is greater than
     *  the length of the array. Use getNumStakers before calling this function to determine the
     *  length of the array.
     * @param _startOffset First offset in the stakers array to return the account number for.
     * @param _numberToReturn The number of accounts to return.
     * @return _stakers A subset of the stakers array.
     */
    function getStakers(uint256 _startOffset, uint256 _numberToReturn)
        external
        view
        returns (address[] memory _stakers)
    {
        address[] memory stakerPartialArray = new address[](_numberToReturn);
        for (uint256 i = 0; i < _numberToReturn; i++) {
            stakerPartialArray[i] = stakers[_startOffset + i];
        }
        return stakerPartialArray;
    }

    /**
     * @notice Add more stake to an account.
     * @dev If the account has a zero balance prior to this call, add the account to the stakers array.
     * @param _account Account to add stake to.
     * @param _amount The amount of stake to add.
     */
    function addStake(address _account, uint256 _amount) private {
        uint256 currentStake = balances[_account];
        if (currentStake == 0) {
            stakers.push(_account);
        }
        uint256 newBalance = currentStake + _amount;
        balances[_account] = newBalance;
        emit StakeAdded(_account, _amount, newBalance);
    }

    // Override the _authorizeUpgrade function
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADE_ROLE) {}

    /// @notice storage gap for additional variables for upgrades
    // slither-disable-start unused-state
    // solhint-disable-next-line var-name-mixedcase
    uint256[20] private __StakeHolderGap;
    // slither-disable-end unused-state
}
