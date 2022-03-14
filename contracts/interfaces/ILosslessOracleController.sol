// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ILosslessSecurityOracle.sol";

interface ILssOracleController {
    function setSecurityOracle(ILssSecurityOracle _oracle) external;
    function setSubscriptionFee(uint256 _sub) external;
    function setSubscriptionToken(IERC20 _token) external;
    function setRiskScore(address[] memory _addresses, uint8[] memory _scores) external;
    function withdrawTokens() external returns(uint256);

    function subscribe(address _address, uint256 _blocks) external;
    function cancelSubscription(address _address) external;

    function getIsSubscribed(address _address) external view returns(bool);

    event NewSecurityOracle(ILssSecurityOracle indexed _securityOracle);
    event NewSubscriptionFee(uint256 indexed _subFee);
    event NewSubscriptionToken(IERC20 indexed _subToken);
    event NewSubscription(address indexed _address, uint256 indexed _blocks);
    event NewCancellation(address indexed _address);
    event NewWithdrawal(uint256 indexed _withdrawPool);
}