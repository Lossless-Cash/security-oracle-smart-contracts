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
    

    /// @notice Test getting risk scores before and after cancelling sub
    /// @notice should not revert but return 0
        function testSecurityOracleGetRiskSubCancel(address _payer, address _sub, uint128 _blocks, address[] memory _addresses, uint8[] memory _scores, uint256 _getScore) public notZero(_payer) notZero(_sub) {
        evm.assume(_getScore <= _addresses.length);
        evm.assume(_getScore <= _scores.length);
        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        
        if (_addresses.length == _scores.length) {
            setUpStartingPoint(_payer, _sub, _blocks, _addresses, _scores, true);
            
            evm.roll(_blocks);
            evm.prank(_sub);
            uint8 riskScore = securityOracle.getRiskScore(_addresses[_getScore]);

            assertEq(riskScore, _scores[_getScore]);

            evm.prank(_payer);
            securityOracle.cancelSubscription(_sub);

            evm.roll(10);
            evm.prank(_sub);
            riskScore = securityOracle.getRiskScore(_addresses[_getScore]);

            assertEq(riskScore, 0);
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

        evm.expectRevert("LSS: Already subscribed");
        securityOracle.subscribe(_sub, _blocks);      
        
        evm.stopPrank();  
    }

    /// @notice Test unsubscribe
    /// @dev Should not revert
    function testSecurityOraclerSubscriptionCancel(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock) public notZero(_payer) notZero(_sub){
        if (_cancelBlock < _blocks && _cancelBlock > 0) {
            uint256 endingBlock = block.number + _blocks;

            generateSubscription(_payer, _sub, _blocks);

            evm.roll(_cancelBlock);
            uint256 _toReturn = (endingBlock - block.number) * subscriptionFee;

            evm.prank(_payer);
            securityOracle.cancelSubscription(_sub);

            assertEq(erc20Token.balanceOf(_payer), _toReturn);
        }
    }

    /// @notice Test unsubscribe after time has passed
    /// @dev Should revert
    function testSecurityOraclerSubscriptionCancelExpired(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub) {
        generateSubscription(_payer, _sub, _blocks);

        evm.roll(_blocks);

        evm.prank(_payer);
        evm.expectRevert("LSS: Not subscribed");
        securityOracle.cancelSubscription(_sub);
    }


    /// @notice Test unsubscribe by non payer
    /// @dev Should revert
    function testSecurityOraclerSubscriptionCancelNonPayer(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock) public notZero(_payer) notZero(_sub) {
        if (_cancelBlock < _blocks && _cancelBlock > 0) {

            uint256 endingBlock = block.number + _blocks;

            generateSubscription(_payer, _sub, _blocks);

            evm.roll(_cancelBlock);

            evm.prank(address(999));
            evm.expectRevert("LSS: Must have payed for sub");
            securityOracle.cancelSubscription(_sub);
        }
    }

    /// @notice Test unsubscribe non subbed
    /// @dev Should revert
    function testSecurityOraclerSubscriptionCancelNonSubbed(address _payer, address _sub, uint128 _blocks, uint256 _cancelBlock) public notZero(_payer) notZero(_sub){
        evm.roll(10);
        if (_cancelBlock < _blocks && _cancelBlock > 0) {
            evm.prank(_payer);
            evm.expectRevert("LSS: Not subscribed");
            securityOracle.cancelSubscription(_sub);
        }
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

        assertEq(erc20Token.balanceOf(securityOwner), subAmount/2);
        assertEq(withdrawed, subAmount/2);
    }

    /// @notice Test withdraw middle of a cycle then cancel sub
    /// @dev Should not revert
    function testSecurityOraclerWithdrawMidCycleThenCancel(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_cancelBlock > 11);
        evm.assume(_cancelBlock < _blocks);
        
        uint256 endingBlock = block.number + _blocks;
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);

        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_cancelBlock);
        uint256 _toReturn = (endingBlock - block.number) * subscriptionFee;
        uint256 _toWithdraw = subAmount - _toReturn;

        evm.prank(securityOwner);
        uint256 withdrawed = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), _toWithdraw);
        assertEq(withdrawed, _toWithdraw);
        evm.prank(_payer);
        securityOracle.cancelSubscription(_sub);

        assertEq(erc20Token.balanceOf(_payer), _toReturn);
    }

    /// @notice Test withdraw middle of a cycle then cancel sub with fee change
    /// @dev Should not revert
    function testSecurityOraclerWithdrawMidCycleThenCancelFeeChange(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock, uint256 _newFee) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_cancelBlock > 11);
        evm.assume(_cancelBlock < _blocks);
        evm.assume(_newFee != subscriptionFee);
        
        uint256 endingBlock = block.number + _blocks;
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);

        assert(securityOracle.getIsSubscribed(_sub));

        evm.prank(securityOwner);
        securityOracle.setSubscriptionFee(_newFee);

        evm.roll(_cancelBlock);
        uint256 _toReturn = (endingBlock - block.number) * subscriptionFee;
        uint256 _toWithdraw = subAmount - _toReturn;

        evm.prank(securityOwner);
        uint256 withdrawed = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), _toWithdraw);
        assertEq(withdrawed, _toWithdraw);
        evm.prank(_payer);
        securityOracle.cancelSubscription(_sub);

        assertEq(erc20Token.balanceOf(_payer), _toReturn);
    }

    /// @notice Test withdraw cancel sub mid cycle then withdraw
    /// @dev Should not revert
    function testSecurityOraclerCancelMidCycleThenWithdraw(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_cancelBlock > 11);
        evm.assume(_cancelBlock < _blocks);
        
        uint256 endingBlock = block.number + _blocks;
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);

        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_cancelBlock);
        uint256 _toReturn = (endingBlock - block.number) * subscriptionFee;
        uint256 _toWithdraw = subAmount - _toReturn;

        evm.prank(_payer);
        securityOracle.cancelSubscription(_sub);

        assertEq(erc20Token.balanceOf(_payer), _toReturn);

        evm.prank(securityOwner);
        uint256 withdrawed = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), _toWithdraw);
        assertEq(withdrawed, _toWithdraw);
    }

    /// @notice Test withdraw cancel sub mid cycle then withdraw with sub change
    /// @dev Should not revert
    function testSecurityOraclerCancelMidCycleThenWithdrawFeeChange(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock, uint256 _newFee) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_cancelBlock > 11);
        evm.assume(_cancelBlock < _blocks);
        evm.assume(_newFee != subscriptionFee);

        uint256 endingBlock = block.number + _blocks;
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);

        assert(securityOracle.getIsSubscribed(_sub));

        evm.prank(securityOwner);
        securityOracle.setSubscriptionFee(_newFee);

        evm.roll(_cancelBlock);
        uint256 _toReturn = (endingBlock - block.number) * subscriptionFee;
        uint256 _toWithdraw = subAmount - _toReturn;

        evm.prank(_payer);
        securityOracle.cancelSubscription(_sub);

        assertEq(erc20Token.balanceOf(_payer), _toReturn);

        evm.prank(securityOwner);
        uint256 withdrawed = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), _toWithdraw);
        assertEq(withdrawed, _toWithdraw);
    }
}
