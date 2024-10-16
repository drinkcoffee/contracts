// Copyright (c) Immutable Pty Ltd 2018 - 2024
// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable-4.9.3/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from "openzeppelin-contracts-upgradeable-4.9.3/access/AccessControlEnumerableUpgradeable.sol";


/**
 * @title StakeHolder - holds stake
 * @dev The StakeHolder contract is designed to be upgradeable.
 */
contract StakeHolder is AccessControlEnumerableUpgradeable, UUPSUpgradeable {

    error MustStakeMoreThanZero();
    error MustDistributeMoreThanZero();
    error UnstakeAmountExceedsBalance(uint256 _amountToUnstake, uint256 _currentStake);
    error RecipientsAmountsMismatch(uint256 _receipientsLength, uint256 _amountsLength);
    error DistributionAmountsDoNotMatchTotal(uint256 _msgValue, uint256 _calculatedTotalDistribution);

    event StakeAdded(address _staker, uint256 _amountAdded, uint256 _newBalance);
    event StakeRemoved(address _staker, uint256 _amountRemoved, uint256 _newBalance);
    event Distributed(address _distributor, uint256 _totalDistribution, uint256 _numRecipients);

    /// @notice Only UPGRADE_ROLE can upgrade the contract
    bytes32 public constant UPGRADE_ROLE = bytes32("UPGRADE_ROLE");

    mapping(address staker => uint256 stake) private balances;

    /// @notice A list of all stakers who have ever staked. 
    /// Note that it is possible that this list will contain duplicates if an account stakes,
    /// then fully unstakes, and then stakes again.
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
     */
    function stake() external payable {
        // TODO reentrancy guard
        if (msg.value == 0) {
            revert MustStakeMoreThanZero();
        }
        addStake(msg.sender, msg.value);
    }

    /**
     * @notice Allow any account to remove some or all of their own stake.
     * @param _amountToUnstake Amount of stake to remove.
     */
    function unstake(uint256 _amountToUnstake) external {
        // TODO reentrancy guard
        uint256 currentStake = balances[msg.sender];
        if (currentStake < _amountToUnstake) {
            revert UnstakeAmountExceedsBalance(_amountToUnstake, currentStake);
        }
        uint256 newBalance = currentStake - _amountToUnstake;
        balances[msg.sender] = newBalance;

        // TODO send the money

        emit StakeRemoved(msg.sender, _amountToUnstake, newBalance);
    }


    /**
     * @notice Any account can distribute tokens to any set of accounts.
     */
    function distributeRewards(address[] calldata _receipients, uint256[] calldata _amounts) external payable {
        // TODO reentrancy guard
        if (msg.value == 0) {
            revert MustDistributeMoreThanZero();
        }

        uint256 len = _receipients.length;
        if (len != _amounts.length) {
            revert RecipientsAmountsMismatch(len, _amounts.length);
        }
        uint256 total = 0;
        for (uint256 i = 0; i < len; i++) {
            uint256 amount = _amounts[i];
            addStake(_receipients[i], amount);
            total += amount;
        }
        if (total != msg.value) {
            revert DistributionAmountsDoNotMatchTotal(msg.value, total);
        }
        emit Distributed(msg.sender, msg.value, len);
    }


    function getBalance(address _account) external view returns(uint256) {
        return balances[_account];
    }

    function getNumStakers() external view returns(uint256) {
        return stakers.length;
    }

    function getStakers(uint256 _startOffset, uint256 _numberToReturn) external view returns(address[] memory) {
        address[] memory stakerPartialArray = new address[](_numberToReturn);
        for (uint256 i = 0; i < _numberToReturn; i++) {
            stakerPartialArray[i] = stakers[_startOffset + i];
        }
        return stakerPartialArray;
    }


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