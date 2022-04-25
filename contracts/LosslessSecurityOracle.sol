// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/TransferHelper.sol";

import "./interfaces/ILosslessSecurityOracle.sol";

contract LosslessSecurityOracle is ILssSecurityOracle, Initializable, ContextUpgradeable, PausableUpgradeable, OwnableUpgradeable, AccessControlUpgradeable {

    IERC20 public subToken;

    uint256 public subFee;
    uint256 public totalUniqueSubs;

    mapping(address => uint256) public subNo;
    mapping(address => uint8) public riskScores;
    mapping(uint256 => Subscription) subscriptions;

    struct Subscription {
        uint256 endingBlock;
        uint256 amount;
    }

    bytes32 public constant ORACLE = keccak256("ORACLE");

    function initialize(address _oracle, uint256 _subscription, IERC20 _subToken) public initializer {
        __Ownable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        setSubscriptionFee(_subscription);
        setSubscriptionToken(_subToken);
        addOracle(_oracle);
        totalUniqueSubs = 0;
    }

    modifier onlyOracle() {
        require(hasRole(ORACLE, msg.sender), "LSS: Only Oracle Controller");
        _;
    }

    /// @notice This function pauses the contract
    function pause() public onlyOwner {
        _pause();
    }    

    /// @notice This function unpauses the contract
    function unpause() public onlyOwner {
        _unpause();
    }

    // --- SETTERS --- 

    /// @notice This function sets the security oracle address
    /// @param _oracle Lossless Oracle Controller address
    function addOracle(address _oracle) override public onlyOwner {
        require(!hasRole(ORACLE, _oracle), "LSS: Cannot set same address");
        grantRole(ORACLE, _oracle);
        emit NewOracle(_oracle);
    }

    /// @notice This function removes an oracle
    /// @param _oracle Lossless Oracle Controller address
    function removeOracle(address _oracle) override public onlyOwner {
        require(hasRole(ORACLE, _oracle), "LSS: Not Oracle");
        revokeRole(ORACLE, _oracle);
        emit NewOracleRemoval(_oracle);
    }

    /// @notice This function sets the new subscription fee
    /// @param _sub token amount per block
    function setSubscriptionFee(uint256 _sub) override public onlyOwner {
        require(subFee != _sub, "LSS: Cannot set same amount");
        subFee = _sub;
        emit NewSubscriptionFee(subFee);
    }

    /// @notice This function sets the subscription token
    /// @param _token token used for subscription
    function setSubscriptionToken(IERC20 _token) override public onlyOwner {
        require(subToken != _token, "LSS: Cannot set same token");
        subToken = _token;
        emit NewSubscriptionToken(subToken);
    }

    // --- RISK MANAGEMENT ---

    /// @notice This function sets the risk score for an address
    /// @param _addresses Array of addresses to add scores
    /// @param _scores Risk score assigned to an address
    function setRiskScores(address[] calldata _addresses, uint8[] calldata _scores) override public onlyOracle {
        uint256 listLen = _addresses.length;

        require(listLen == _scores.length, "LSS: Arrays do not match");

        for(uint256 i = 0; i < listLen;) {
            address updatedAddress = _addresses[i];
            uint8 updatedScore = _scores[i];

            riskScores[updatedAddress] = updatedScore;
            
            emit NewRiskScore(updatedAddress, updatedScore);

            unchecked {i++;}
        }
    }
    // --- GETTERS ---

    /// @notice This function returns the risk score of an address
    /// @param _address address to check
    function getRiskScore(address _address) override public view returns(uint8) {
        if (!getIsSubscribed(msg.sender)) {
            return 0;
        } else {
            return riskScores[_address];
        }
    }

    /// @notice This function returns if an address is subsribed
    /// @param _address address to check
    function getIsSubscribed(address _address) override public view returns(bool) {
        if (subFee == 0) {
            return true;
        }
        return(block.number <= subscriptions[subNo[_address]].endingBlock);
    }

// --- SUBSCRIPTIONS ---

    /// @notice This function starts a new subscription
    /// @param _address address to subscribe
    /// @param _blocks amount of blocks to subscribe
    function subscribe(address _address, uint256 _blocks) override public {
        require(_address != address(0), "LSS: Cannot sub zero address");
        require(subNo[_address] == 0, "LSS: Already subscribed, extend");

        totalUniqueSubs += 1;
        subNo[_address] = totalUniqueSubs;

        Subscription storage sub = subscriptions[subNo[_address]];

        uint256 amountToPay = _blocks * subFee;

        TransferHelper.safeTransferFrom(address(subToken), msg.sender, address(this), amountToPay);

        sub.endingBlock = block.number + _blocks;
        sub.amount = amountToPay;

        emit NewSubscription(_address, _blocks);
    }

    /// @notice This function extends a subscription
    /// @param _address address to extend
    function extendSubscription(address _address, uint256 _blocks) override public {
        Subscription storage sub = subscriptions[subNo[_address]];
        require(sub.endingBlock != 0, "LSS: Not subscribed");

        uint256 amountToPay = _blocks * subFee;

        TransferHelper.safeTransferFrom(address(subToken), msg.sender, address(this), amountToPay);

        if (block.number <= sub.endingBlock) {
            sub.endingBlock += _blocks;
        } else {
            sub.endingBlock = block.number + _blocks;
        }
        
        sub.amount += amountToPay;

        emit NewSubscriptionExtension(_address, _blocks);
    }


    /// @notice This function withdraws the tokens coming from subscriptions
    function withdrawTokens() override public onlyOwner returns(uint256) {
        uint256 withdrawPool = 0;

        for (uint256 i = 0; i <= totalUniqueSubs;) {
            Subscription storage sub = subscriptions[i];

            if (sub.amount != 0) {
                withdrawPool += sub.amount;
                sub.amount = 0;
            }
            unchecked {i++;}
        }

        TransferHelper.safeTransfer(address(subToken), msg.sender, withdrawPool);

        emit NewWithdrawal(withdrawPool);
        return withdrawPool;
    }
}
