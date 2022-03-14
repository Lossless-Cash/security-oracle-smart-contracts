// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./utils/LosslessDevEnvironment.t.sol";

contract LosslessSecurityOracleTests is LosslessDevEnvironment {

    /// @notice Generate risk scores and sub
    function setUpStartingPoint(address _payer, address _sub, uint128 _blocks, address[] memory _addresses, uint8[] memory _scores, bool _subbed) public {
        // Set risk scores
        evm.startPrank(oracle);
        securityOracle.setRiskScores(_addresses, _scores);
        
        for (uint256 i; i < _addresses.length; i++) {
            assertEq(securityOracle.getRiskScore(_addresses[i]), _scores[i]);
        }
        
        evm.stopPrank();

        if (_subbed) {
            generateSubscription(_payer, _sub, _blocks);
            assert(securityOracle.getIsSubscribed(_sub));
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

    /// @notice Test Subscription Fee Set up
    /// @dev Should not revert
    function testSecurityOraclerSetSubscriptionFee(uint256 _newFee) public {
        evm.startPrank(securityOwner);
        if (securityOracle.subFee() == _newFee){
            evm.expectRevert("LSS: Cannot set same amount");
        }
        securityOracle.setSubscriptionFee(_newFee);
        assertEq(securityOracle.subFee(), _newFee);
        evm.stopPrank();
    }

    /// @notice Test Subscription Fee Set up by non owner
    /// @dev Should revert
    function testSecurityOraclerSetSubscriptionFeeNonOwner(uint256 _newFee, address _impersonator) public notOwner(_impersonator) {
        evm.prank(_impersonator);
        evm.expectRevert("Ownable: caller is not the owner");
        securityOracle.setSubscriptionFee(_newFee);
    }

    /// @notice Test Subscription Token Set up
    /// @dev Should not revert
    function testSecurityOraclerSetSubscriptionToken(address _newToken) public {
        evm.startPrank(securityOwner);
        if (address(securityOracle.subToken()) == _newToken) {
            evm.expectRevert("LSS: Cannot set same token");
        }
        securityOracle.setSubscriptionToken(IERC20(_newToken));
        assertEq(address(securityOracle.subToken()), _newToken);
        evm.stopPrank();
    }

    /// @notice Test Subscription Token Set up by non owner
    /// @dev Should revert
    function testSecurityOraclerSetSubscriptionTokenNonOwner(address _newToken, address _impersonator) public notOwner(_impersonator) {
        evm.prank(_impersonator);
        evm.expectRevert("Ownable: caller is not the owner");
        securityOracle.setSubscriptionToken(IERC20(_newToken));
    }
    
    /// @notice Test subscription
    /// @dev Should not revert
    function testSecurityOraclerSubscription(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub){
        generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));
    }

    /// @notice Test subscribe twice
    /// @dev Should revert
    function testSecurityOraclerSubscriptionTwice(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub){
        evm.assume(_blocks > 0);
        generateSubscription(_payer, _sub, _blocks);
        
        uint256 subAmount = _blocks * subscriptionFee;
    
        evm.prank(erc20Admin);
        erc20Token.transfer(_payer, subAmount);

        evm.startPrank(_payer);
        erc20Token.approve(address(securityOracle), subAmount);

        evm.expectRevert("LSS: Already subscribed, extend");
        securityOracle.subscribe(_sub, _blocks);      
        
        evm.stopPrank();  
    }

    /// @notice Test set risk scores
    /// @dev Should not revert
    function testSecurityOraclerSetRiskScores(address[] memory _addresses, uint8[] memory _scores) public {
        evm.startPrank(oracle);
        if (_addresses.length == _scores.length) {
            securityOracle.setRiskScores(_addresses, _scores);
            
            for (uint256 i; i < _addresses.length; i++) {
                assertEq(securityOracle.getRiskScore(_addresses[i]), _scores[i]);
            }
        }
        evm.stopPrank();
    }   

    /// @notice Test set risk scores unmatching arrays
    /// @dev Should revert
    function testSecurityOraclerSetRiskScoresUnmatchingArrays(address[] memory _addresses, uint8[] memory _scores) public {
        evm.startPrank(oracle);
        if (_addresses.length != _scores.length) {
            evm.expectRevert("LSS: Arrays do not match");
            securityOracle.setRiskScores(_addresses, _scores);
        }
        evm.stopPrank();
    }

    /// @notice Test set risk scores non oracle
    /// @dev Should revert
    function testSecurityOraclerSetRiskScoresNonOracle(address[] memory _addresses, uint8[] memory _scores) public {
        evm.startPrank(address(9999));
        if (_addresses.length == _scores.length) {
            evm.expectRevert("LSS: Only Oracle Controller");
            securityOracle.setRiskScores(_addresses, _scores);
        }
        evm.stopPrank();
    }

    /// @notice Test withdraw one full cycle
    /// @dev Should not revert
    function testSecurityOraclerWithdraw(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks + 10);

        evm.prank(securityOwner);
        uint256 withdrawed = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), subAmount);
        assertEq(withdrawed, subAmount);
    }

    /// @notice Test withdraw middle of a cycle
    /// @dev Should not revert
    function testSecurityOraclerWithdrawMidCycle(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks/2);

        evm.prank(securityOwner);
        uint256 withdrawed = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), subAmount);
        assertEq(withdrawed, subAmount);
    }

    /// @notice Test subscription extension
    /// @dev Should not revert
    function testSecurityOracleExtendSub(address _payer, address _sub, uint128 _blocks, uint128 _extension) public notZero(_payer) notZero(_sub) notOwner(_payer){
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 0);
        evm.assume(_extension < type(uint128).max - 100);
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks + 1);
        assert(!securityOracle.getIsSubscribed(_sub));

        extendSubscription(_payer, _sub, _extension);

        assert(securityOracle.getIsSubscribed(_sub));
    }

    /// @notice Test subscription extension for non subscribed
    /// @dev Should revert
    function testSecurityOracleExtendSubNonSubbed(address _payer, address _sub, uint128 _blocks, uint128 _extension) public notZero(_payer) notZero(_sub) notOwner(_payer){
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 0);
        evm.assume(_extension < type(uint128).max - 100);
    
       evm.expectRevert("LSS: Not subscribed");
       securityOracle.extendSubscription(_sub, _extension);
    }

    /// @notice Test subscription extension by anyone
    /// @dev Should not revert
    function testSecurityOracleExtendSubByAnyone(address _payer, address _sub, uint128 _blocks, uint128 _extension, address _extender) public notZero(_payer) notZero(_sub) notOwner(_payer){
        evm.assume(_extender != _payer);
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 0);
        evm.assume(_extension < type(uint128).max - 100);
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks + 1);
        assert(!securityOracle.getIsSubscribed(_sub));

        extendSubscription(_extender, _sub, _extension);

        assert(securityOracle.getIsSubscribed(_sub));
    }

    /// @notice Test subscription extension multiple times
    /// @dev Should not revert
    function testSecurityOracleExtendSubMultiple(address _payer, address _sub, uint128 _blocks, uint128 _extension) public notZero(_payer) notZero(_sub) notOwner(_payer){
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 0);
        evm.assume(_extension < type(uint128).max - 100);
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks + 1);
        assert(!securityOracle.getIsSubscribed(_sub));

        extendSubscription(_payer, _sub, _extension);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks + _extension + 100);
        extendSubscription(_payer, _sub, _extension);
        assert(securityOracle.getIsSubscribed(_sub));
    }

    /// @notice Test subscription extension on already extended period
    /// @dev Should revert
    function testSecurityOracleExtendSubSamePeriod(address _payer, address _sub, uint128 _blocks, uint128 _extension) public notZero(_payer) notZero(_sub) notOwner(_payer){
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 0);
        evm.assume(_extension < type(uint128).max - 100);

        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks + 1);
        assert(!securityOracle.getIsSubscribed(_sub));

        extendSubscription(_payer, _sub, _extension);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.startPrank(_payer);
        evm.expectRevert("LSS: Extension period covered");
        securityOracle.extendSubscription(_sub, _extension/2);      
    }
    
    /// @notice Test withdraw before and after extension
    /// @dev Should not revert
    function testSecurityOracleExtendSubWithdrawing(address _payer, address _sub, uint128 _blocks, uint128 _extension) public notZero(_payer) notZero(_sub) notOwner(_payer){
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 0);
        evm.assume(_extension < type(uint128).max - 100);

        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.prank(securityOwner);
        uint256 withdrawed = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), subAmount);
        assertEq(withdrawed, subAmount);

        evm.roll(_blocks + 1);
        assert(!securityOracle.getIsSubscribed(_sub));

        uint256 extendAmount = extendSubscription(_payer, _sub, _extension);
        
        evm.prank(securityOwner);
        uint256 withdrawedExt = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), subAmount + extendAmount);
        assertEq(withdrawedExt, extendAmount);
    }

    /// @notice Test withdraw before and after extension with fee change
    /// @dev Should not revert
    function testSecurityOracleExtendSubWithdrawing(address _payer, address _sub, uint128 _blocks, uint128 _extension, uint128 _newFee) public notZero(_payer) notZero(_sub) notOwner(_payer){
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 0);
        evm.assume(_extension < type(uint128).max - 100);
        evm.assume(_newFee != subscriptionFee);
        evm.assume(_newFee > 0);

        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.prank(securityOwner);
        uint256 withdrawed = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), subAmount);
        assertEq(withdrawed, subAmount);

        subscriptionFee = _newFee;
        evm.prank(securityOwner);
        securityOracle.setSubscriptionFee(subscriptionFee);

        evm.roll(_blocks + 1);
        assert(!securityOracle.getIsSubscribed(_sub));

        uint256 extendAmount = extendSubscription(_payer, _sub, _extension);
        
        evm.prank(securityOwner);
        uint256 withdrawedExt = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), subAmount + extendAmount);
        assertEq(withdrawedExt, extendAmount);
    }
}
