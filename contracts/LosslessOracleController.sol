// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/TransferHelper.sol";

import "./interfaces/ILosslessOracleController.sol";
import "./LosslessSecurityOracle.sol";

contract LosslessOracleController is ILssOracleController, Initializable, ContextUpgradeable, PausableUpgradeable, OwnableUpgradeable {

    ILssSecurityOracle public lssSecurityOracle;

    IERC20 public subToken;
    uint256 public subFee;
    uint256 public totalUniqueSubs;

    mapping(address => uint256) public subNo;
    mapping(uint256 => Subscription) subscriptions;

    struct Subscription {
        uint256 endingBlock;
        uint256 feeSnapshot;
        uint256 amount;
        address payedBy;
    }

    function initialize(uint256 _subsricption, IERC20 _subToken) public initializer {
        __Ownable_init();
        setSubscriptionFee(_subsricption);
        setSubscriptionToken(_subToken);
        totalUniqueSubs = 0;
    }


    /// @notice This function pauses the contract
    function pause() public onlyOwner {
        _pause();
    }    

    /// @notice This function unpauses the contract
    function unpause() public onlyOwner {
        _unpause();
    }

    // --- GETTERS ---

    /// @notice This function returns if an address is subsribed
    /// @param _address address to verify
    function getIsSubscribed(address _address) override public view returns(bool) {
        return(block.number <= subscriptions[subNo[_address]].endingBlock);
    }

    // --- SETTERS ---

    /// @notice This function sets the security oracle address
    /// @param _oracle oracle address
    function setSecurityOracle(ILssSecurityOracle _oracle) override public onlyOwner {
        require(lssSecurityOracle != _oracle, "LSS: Cannot set same address");
        lssSecurityOracle = _oracle;
        emit NewSecurityOracle(lssSecurityOracle);
    }

    /// @notice This function sets the new subscription fee
    /// @param _sub token amount per block
    function setSubscriptionFee(uint256 _sub) override public onlyOwner {
        require(subFee != _sub, "LSS: Cannot set same amount");
        subFee = _sub;
        emit NewSubscriptionFee(subFee);
    }

    /// @notice This function sets the subscription token
    /// @param _token token for subscribe
    function setSubscriptionToken(IERC20 _token) override public onlyOwner {
        require(subToken != _token, "LSS: Cannot set same token");
        subToken = _token;
        emit NewSubscriptionToken(subToken);
    }

    // --- RISK MANAGEMENT ---

    /// @notice This function interacts with the Security Oracle to update risk scores
    /// @param _addresses addresses to change risk score
    /// @param _scores risk score
    function setRiskScore(address[] memory _addresses, uint8[] memory _scores) override public onlyOwner {
        require(_addresses.length == _scores.length, "LSS: Arrays do not match");
        lssSecurityOracle.setRiskScores(_addresses, _scores);
    }

    // --- SUBSCRIPTIONS ---

    /// @notice This function starts a new subscription
    /// @param _address address to subscribe
    /// @param _blocks amount of blocks to subscribe
    function subscribe(address _address, uint256 _blocks) override public {
        require(_address != address(0), "LSS: Cannot sub zero address");

        if (subNo[_address] == 0){
            totalUniqueSubs += 1;
            subNo[_address] = totalUniqueSubs;
        }

        Subscription storage sub = subscriptions[subNo[_address]];
        require(block.number >= sub.endingBlock, "LSS: Already subscribed");

        uint256 amountToPay = _blocks * subFee;

        TransferHelper.safeTransferFrom(address(subToken), msg.sender, address(this), amountToPay);

        sub.endingBlock = block.number + _blocks;
        sub.feeSnapshot = subFee;
        sub.payedBy = msg.sender;
        sub.amount = amountToPay;

        emit NewSubscription(_address, _blocks);
    }

    /// @notice This function cancels a subscription
    /// @param _address address to unsubscribe
    function cancelSubscription(address _address) override public {
        Subscription storage sub = subscriptions[subNo[_address]];
        require(block.number < sub.endingBlock, "LSS: Not subscribed");
        require(sub.payedBy == msg.sender, "LSS: Must have payed for sub");

        uint256 _returnAmount = (sub.endingBlock - block.number) * sub.feeSnapshot;

        sub.endingBlock = block.number;
        sub.amount -= _returnAmount;
        sub.feeSnapshot = 0;

        TransferHelper.safeTransfer(address(subToken), msg.sender, _returnAmount);

        emit NewCancellation(_address);
    }

    /// @notice This withdraws all the tokens from previous 
    function withdrawTokens() override public onlyOwner returns(uint256) {
        uint256 withdrawPool = 0;

        for (uint256 i = 0; i <= totalUniqueSubs;) {
            Subscription storage sub = subscriptions[i];

            if (block.number > sub.endingBlock) {
                withdrawPool += sub.amount;
                sub.amount = 0;
            } else {
                uint256 remaining = (sub.endingBlock - block.number) * sub.feeSnapshot;
                withdrawPool = sub.amount - remaining;
                sub.amount = remaining; 
            }
            unchecked {i++;}
        }

        TransferHelper.safeTransfer(address(subToken), msg.sender, withdrawPool);

        emit NewWithdrawal(withdrawPool);
        return(withdrawPool);
    }
}