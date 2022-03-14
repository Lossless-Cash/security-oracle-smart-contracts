// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ILosslessOracleController.sol";

interface ILssSecurityOracle {
    function setOracleController(ILssOracleController _controller) external;
    function setRiskScores(address[] memory _addresses, uint8[] memory _scores) external;
    
    function getRiskScore(address _address) external returns (uint8);

    event NewOracleController(ILssOracleController indexed _oracleController);
    event NewRiskScore(address indexed _updatedAddress, uint8 indexed _updatedScore);
}