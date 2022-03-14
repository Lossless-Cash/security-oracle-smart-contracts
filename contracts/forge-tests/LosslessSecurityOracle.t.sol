// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./utils/LosslessDevEnvironment.t.sol";

contract LosslessSecurityOracleTests is LosslessDevEnvironment {

    /// @notice Generate risk scores and sub
    function setUpStartingPoint(address _payer, address _sub, uint128 _blocks, address[] memory _addresses, uint8[] memory _scores, bool _subbed) public {
        // Set risk scores
        evm.startPrank(address(oracleOwner));
        
        oracleController.setRiskScore(_addresses, _scores);
        
        for (uint256 i; i < _addresses.length; i++) {
            assertEq(securityOracle.getRiskScore(_addresses[i]), _scores[i]);
        }
        
        evm.stopPrank();

        if (_subbed) {
            generateSubscription(_payer, _sub, _blocks);
            assert(oracleController.getIsSubscribed(_sub));
        }
    }

    /// @notice Test getting risk scores with subscription
    /// @notice should not revert
    function testSecurityOracleGetRiskSubActive(address _payer, address _sub, uint128 _blocks, address[] memory _addresses, uint8[] memory _scores, uint256 _getScore) public notZero(_payer) notZero(_sub) {
        evm.assume(_getScore < _addresses.length);
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        
        if (_addresses.length == _scores.length) {
            setUpStartingPoint(_payer, _sub, _blocks, _addresses, _scores, true);
            
            evm.roll(5);
            evm.startPrank(_sub);
            uint8 riskScore = securityOracle.getRiskScore(_addresses[_getScore]);

            assertEq(riskScore, _scores[_getScore]);
            evm.stopPrank();
        }
    }

    /// @notice Test getting risk scores subscription expired
    /// @notice should not revert but return 0
    function testSecurityOracleGetRiskSubExpired(address _payer, address _sub, uint128 _blocks, address[] memory _addresses, uint8[] memory _scores, uint256 _getScore) public notZero(_payer) notZero(_sub) {
        evm.assume(_getScore < _addresses.length);
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        
        if (_addresses.length == _scores.length) {
            setUpStartingPoint(_payer, _sub, _blocks, _addresses, _scores, true);
            
            evm.roll(_blocks + 1);
            evm.startPrank(_sub);
            uint8 riskScore = securityOracle.getRiskScore(_addresses[_getScore]);

            assertEq(riskScore, 0);
            evm.stopPrank();
        }
    }


    /// @notice Test getting risk scores without subscription
    /// @notice should not revert but return 0
    function testSecurityOracleGetRiskSubNone(address _payer, address _sub, uint128 _blocks, address[] memory _addresses, uint8[] memory _scores, uint256 _getScore) public notZero(_payer) notZero(_sub) {
        evm.assume(_getScore < _addresses.length);
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        
        if (_addresses.length == _scores.length) {
            setUpStartingPoint(_payer, _sub, _blocks, _addresses, _scores, false);
            
            evm.roll(5);
            evm.startPrank(_sub);
            uint8 riskScore = securityOracle.getRiskScore(_addresses[_getScore]);

            assertEq(riskScore, 0);
            evm.stopPrank();
        }
    }
    

    /// @notice Test getting risk scores before and after cancelling sub
    /// @notice should not revert but return 0
        function testSecurityOracleGetRiskSubCancel(address _payer, address _sub, uint128 _blocks, address[] memory _addresses, uint8[] memory _scores, uint256 _getScore) public notZero(_payer) notZero(_sub) {
        evm.assume(_getScore < _addresses.length);
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        
        if (_addresses.length == _scores.length) {
            setUpStartingPoint(_payer, _sub, _blocks, _addresses, _scores, true);
            
            evm.roll(5);
            evm.prank(_sub);
            uint8 riskScore = securityOracle.getRiskScore(_addresses[_getScore]);

            assertEq(riskScore, _scores[_getScore]);

            evm.prank(_payer);
            oracleController.cancelSubscription(_sub);

            evm.roll(1);
            evm.prank(_sub);
            riskScore = securityOracle.getRiskScore(_addresses[_getScore]);

            assertEq(riskScore, 0);
        }
    }
}
