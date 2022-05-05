// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/TransferHelper.sol";

import "./interfaces/ILosslessSecurityOracle.sol";

contract LosslessSecurityOracle is
    ILssSecurityOracle,
    Initializable,
    ContextUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable
{
    IERC20 public subToken;

    uint256 public subFee;

    mapping(address => uint8) public riskScores;
    mapping(address => Subscription) subscriptions;

    struct Subscription {
        uint256 endingBlock;
        uint256 amount;
    }

    bytes32 public constant ORACLE = keccak256("ORACLE");

    function initialize(
        address _oracle,
        uint256 _subscription,
        IERC20 _subToken
    ) public initializer {
        __Context_init_unchained();
        __Pausable_init_unchained();
        __Ownable_init_unchained();
        __AccessControl_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        setSubscriptionFee(_subscription);
        setSubscriptionToken(_subToken);
        addOracle(_oracle);
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
    function addOracle(address _oracle) public override onlyOwner {
        require(!hasRole(ORACLE, _oracle), "LSS: Cannot set same address");
        grantRole(ORACLE, _oracle);
    }

    /// @notice This function removes an oracle
    /// @param _oracle Lossless Oracle Controller address
    function removeOracle(address _oracle) public override onlyOwner {
        require(hasRole(ORACLE, _oracle), "LSS: Not Oracle");
        revokeRole(ORACLE, _oracle);
    }

    /// @notice This function sets the new subscription fee
    /// @param _sub token amount per block
    function setSubscriptionFee(uint256 _sub) public override onlyOwner {
        subFee = _sub;
        emit NewSubscriptionFee(subFee);
    }

    /// @notice This function sets the subscription token
    /// @param _token token used for subscription
    function setSubscriptionToken(IERC20 _token) public override onlyOwner {
        subToken = _token;
        emit NewSubscriptionToken(subToken);
    }

    // --- RISK MANAGEMENT ---

    /// @notice This function sets the risk score for an array of addresses
    /// @param newScores Array of new addresses with scores using the RiskScores struct
    function setRiskScores(RiskScores[] calldata newScores) public onlyOracle {
        uint256 arrayLen = newScores.length;
        for (uint256 i = 0; i < arrayLen;i++) {
            RiskScores memory scores = newScores[i];

            riskScores[scores.addr] = scores.score;

            emit NewRiskScore(scores.addr, scores.score);
        }
    }

    // --- GETTERS ---

    /// @notice This function returns the risk score of an address
    /// @param _address address to check
    function getRiskScore(address _address)
        public
        view
        override
        returns (uint8)
    {
        if (!getIsSubscribed(msg.sender)) {
            return 0;
        } else {
            return riskScores[_address];
        }
    }

    /// @notice This function returns if an address is subscribed
    /// @param _address address to check
    function getIsSubscribed(address _address)
        public
        view
        override
        returns (bool)
    {
        if (subFee == 0) {
            return true;
        } else {
            return (block.number <= subscriptions[_address].endingBlock);
        }
    }

    // --- SUBSCRIPTIONS ---

    /// @notice This function starts a new subscription
    /// @param _address address to subscribe
    /// @param _blocks amount of blocks to subscribe
    function subscribe(address _address, uint256 _blocks) public override {
        require(_blocks > 100, "LSS: Minimum 101 blocks");
        require(_address != address(0), "LSS: Cannot sub zero address");
        
        Subscription storage sub = subscriptions[_address];

        uint256 amountToPay = _blocks * subFee;

        if (block.number <= sub.endingBlock) {
            sub.endingBlock += _blocks;
        } else {
            sub.endingBlock = block.number + _blocks;
        }

        sub.amount += amountToPay;

        TransferHelper.safeTransferFrom(
            address(subToken),
            msg.sender,
            address(this),
            amountToPay
        );

        emit NewSubscription(_address, _blocks);
    }

    /// @notice This function withdraws the tokens coming from subscriptions
    function withdrawTokens() public override onlyOwner returns (uint256) {

        uint256 withdrawPool = subToken.balanceOf(address(this));

        TransferHelper.safeTransfer(
            address(subToken),
            msg.sender,
            withdrawPool
        );

        emit NewWithdrawal(withdrawPool);
        return withdrawPool;
    }
}
