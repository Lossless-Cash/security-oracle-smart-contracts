// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./utils/LosslessDevEnvironment.t.sol";

contract LosslessOracleControllerTests is LosslessDevEnvironment {

    /// @notice Test Security Oracle Set up
    /// @dev Should not revert
    function testOracleControllerSetSecurityOracle(address _oracle) public {
        evm.startPrank(oracleOwner);
        if (address(oracleController.lssSecurityOracle()) == _oracle) {
            evm.expectRevert("LSS: Cannot set same address");
        }
        oracleController.setSecurityOracle(ILssSecurityOracle(_oracle));
        assertEq(address(oracleController.lssSecurityOracle()), address(_oracle));
        evm.stopPrank();
    }
        
    /// @notice Test Security Oracle Set up non owner
    /// @dev Should revert
    function testOracleControllerSetSecurityOracleNonOwner(address _impersonator, address _oracle) public notOwner(_impersonator) {
        evm.prank(_impersonator);
        evm.expectRevert("Ownable: caller is not the owner");
        oracleController.setSecurityOracle(ILssSecurityOracle(_oracle));
    }

    /// @notice Test Subscription Fee Set up
    /// @dev Should not revert
    function testOracleControllerSetSubscriptionFee(uint256 _newFee) public {
        evm.startPrank(oracleOwner);
        if (oracleController.subFee() == _newFee){
            evm.expectRevert("LSS: Cannot set same amount");
        }
        oracleController.setSubscriptionFee(_newFee);
        assertEq(oracleController.subFee(), _newFee);
        evm.stopPrank();
    }

    /// @notice Test Subscription Fee Set up by non owner
    /// @dev Should revert
    function testOracleControllerSetSubscriptionFeeNonOwner(uint256 _newFee, address _impersonator) public notOwner(_impersonator) {
        evm.prank(_impersonator);
        evm.expectRevert("Ownable: caller is not the owner");
        oracleController.setSubscriptionFee(_newFee);
    }

    /// @notice Test Subscription Token Set up
    /// @dev Should not revert
    function testOracleControllerSetSubscriptionToken(address _newToken) public {
        evm.startPrank(oracleOwner);
        if (address(oracleController.subToken()) == _newToken) {
            evm.expectRevert("LSS: Cannot set same token");
        }
        oracleController.setSubscriptionToken(IERC20(_newToken));
        assertEq(address(oracleController.subToken()), _newToken);
        evm.stopPrank();
    }

    /// @notice Test Subscription Token Set up by non owner
    /// @dev Should revert
    function testOracleControllerSetSubscriptionTokenNonOwner(address _newToken, address _impersonator) public notOwner(_impersonator) {
        evm.prank(_impersonator);
        evm.expectRevert("Ownable: caller is not the owner");
        oracleController.setSubscriptionToken(IERC20(_newToken));
    }
    
    /// @notice Test subscription
    /// @dev Should not revert
    function testOracleControllerSubscription(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub){
        generateSubscription(_payer, _sub, _blocks);
        assert(oracleController.getIsSubscribed(_sub));
    }

    /// @notice Test subscribe twice
    /// @dev Should revert
    function testOracleControllerSubscriptionTwice(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub){
        evm.assume(_blocks > 0);
        generateSubscription(_payer, _sub, _blocks);
        
        uint256 subAmount = _blocks * subscriptionFee;
    
        evm.prank(erc20Admin);
        erc20Token.transfer(_payer, subAmount);

        evm.startPrank(_payer);
        erc20Token.approve(address(oracleController), subAmount);

        evm.expectRevert("LSS: Already subscribed");
        oracleController.subscribe(_sub, _blocks);      
        
        evm.stopPrank();  
    }

    /// @notice Test unsubscribe
    /// @dev Should not revert
    function testOracleControllerSubscriptionCancel(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock) public notZero(_payer) notZero(_sub){
        if (_cancelBlock < _blocks && _cancelBlock > 0) {
            uint256 endingBlock = block.number + _blocks;

            generateSubscription(_payer, _sub, _blocks);

            evm.roll(_cancelBlock);
            uint256 _toReturn = (endingBlock - block.number) * subscriptionFee;

            evm.prank(_payer);
            oracleController.cancelSubscription(_sub);

            assertEq(erc20Token.balanceOf(_payer), _toReturn);
        }
    }

    /// @notice Test unsubscribe after time has passed
    /// @dev Should revert
    function testOracleControllerSubscriptionCancelExpired(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub) {
        generateSubscription(_payer, _sub, _blocks);

        evm.roll(_blocks);

        evm.prank(_payer);
        evm.expectRevert("LSS: Not subscribed");
        oracleController.cancelSubscription(_sub);
    }


    /// @notice Test unsubscribe by non payer
    /// @dev Should revert
    function testOracleControllerSubscriptionCancelNonPayer(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock) public notZero(_payer) notZero(_sub) {
        if (_cancelBlock < _blocks && _cancelBlock > 0) {

            uint256 endingBlock = block.number + _blocks;

            generateSubscription(_payer, _sub, _blocks);

            evm.roll(_cancelBlock);
            uint256 _toReturn = (endingBlock - block.number) * subscriptionFee;

            evm.prank(address(999));
            evm.expectRevert("LSS: Must have payed for sub");
            oracleController.cancelSubscription(_sub);
        }
    }

    /// @notice Test unsubscribe non subbed
    /// @dev Should revert
    function testOracleControllerSubscriptionCancelNonSubbed(address _payer, address _sub, uint128 _blocks, uint256 _cancelBlock) public notZero(_payer) notZero(_sub){
        evm.roll(10);
        if (_cancelBlock < _blocks && _cancelBlock > 0) {
            evm.prank(_payer);
            evm.expectRevert("LSS: Not subscribed");
            oracleController.cancelSubscription(_sub);
        }
    }

    /// @notice Test set risk scores
    /// @dev Should not revert
    function testOracleControllerSetRiskScores(address[] memory _addresses, uint8[] memory _scores) public {
        evm.startPrank(address(oracleOwner));
        if (_addresses.length == _scores.length) {
            oracleController.setRiskScore(_addresses, _scores);
            
            for (uint256 i; i < _addresses.length; i++) {
                assertEq(securityOracle.getRiskScore(_addresses[i]), _scores[i]);
            }
        }
        evm.stopPrank();
    }   

    /// @notice Test set risk scores unmatching arrays
    /// @dev Should revert
    function testOracleControllerSetRiskScoresUnmatchingArrays(address[] memory _addresses, uint8[] memory _scores) public {
        evm.startPrank(address(oracleOwner));
        if (_addresses.length != _scores.length) {
            evm.expectRevert("LSS: Arrays do not match");
            oracleController.setRiskScore(_addresses, _scores);
        }
        evm.stopPrank();
    }

    /// @notice Test set risk scores non owner
    /// @dev Should revert
    function testOracleControllerSetRiskScoresNonOwner(address[] memory _addresses, uint8[] memory _scores) public {
        evm.startPrank(address(9999));
        if (_addresses.length == _scores.length) {
            evm.expectRevert("Ownable: caller is not the owner");
            oracleController.setRiskScore(_addresses, _scores);
        }
        evm.stopPrank();
    }

    /// @notice Test withdraw one full cycle
    /// @dev Should not revert
    function testOracleControllerWithdraw(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(oracleController.getIsSubscribed(_sub));

        evm.roll(_blocks + 10);

        evm.prank(oracleOwner);
        uint256 withdrawed = oracleController.withdrawTokens();

        assertEq(erc20Token.balanceOf(oracleOwner), subAmount);
        assertEq(withdrawed, subAmount);
    }

    /// @notice Test withdraw middle of a cycle
    /// @dev Should not revert
    function testOracleControllerWithdrawMidCycle(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(oracleController.getIsSubscribed(_sub));

        evm.roll(_blocks/2);

        evm.prank(oracleOwner);
        uint256 withdrawed = oracleController.withdrawTokens();

        assertEq(erc20Token.balanceOf(oracleOwner), subAmount/2);
        assertEq(withdrawed, subAmount/2);
    }

    /// @notice Test withdraw middle of a cycle then cancel sub
    /// @dev Should not revert
    function testOracleControllerWithdrawMidCycleThenCancel(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_cancelBlock > 11);
        evm.assume(_cancelBlock < _blocks);
        
        uint256 endingBlock = block.number + _blocks;
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);

        assert(oracleController.getIsSubscribed(_sub));

        evm.roll(_cancelBlock);
        uint256 _toReturn = (endingBlock - block.number) * subscriptionFee;
        uint256 _toWithdraw = subAmount - _toReturn;

        evm.prank(oracleOwner);
        uint256 withdrawed = oracleController.withdrawTokens();

        assertEq(erc20Token.balanceOf(oracleOwner), _toWithdraw);
        assertEq(withdrawed, _toWithdraw);
        evm.prank(_payer);
        oracleController.cancelSubscription(_sub);

        assertEq(erc20Token.balanceOf(_payer), _toReturn);
    }

    /// @notice Test withdraw middle of a cycle then cancel sub with fee change
    /// @dev Should not revert
    function testOracleControllerWithdrawMidCycleThenCancel(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock, uint256 _newFee) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_cancelBlock > 11);
        evm.assume(_cancelBlock < _blocks);
        evm.assume(_newFee != subscriptionFee);
        
        uint256 endingBlock = block.number + _blocks;
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);

        assert(oracleController.getIsSubscribed(_sub));

        evm.prank(oracleOwner);
        oracleController.setSubscriptionFee(_newFee);

        evm.roll(_cancelBlock);
        uint256 _toReturn = (endingBlock - block.number) * subscriptionFee;
        uint256 _toWithdraw = subAmount - _toReturn;

        evm.prank(oracleOwner);
        uint256 withdrawed = oracleController.withdrawTokens();

        assertEq(erc20Token.balanceOf(oracleOwner), _toWithdraw);
        assertEq(withdrawed, _toWithdraw);
        evm.prank(_payer);
        oracleController.cancelSubscription(_sub);

        assertEq(erc20Token.balanceOf(_payer), _toReturn);
    }

    /// @notice Test withdraw cancel sub mid cycle then withdraw
    /// @dev Should not revert
    function testOracleControllerCancelMidCycleThenWithdraw(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_cancelBlock > 11);
        evm.assume(_cancelBlock < _blocks);
        
        uint256 endingBlock = block.number + _blocks;
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);

        assert(oracleController.getIsSubscribed(_sub));

        evm.roll(_cancelBlock);
        uint256 _toReturn = (endingBlock - block.number) * subscriptionFee;
        uint256 _toWithdraw = subAmount - _toReturn;

        evm.prank(_payer);
        oracleController.cancelSubscription(_sub);

        assertEq(erc20Token.balanceOf(_payer), _toReturn);

        evm.prank(oracleOwner);
        uint256 withdrawed = oracleController.withdrawTokens();

        assertEq(erc20Token.balanceOf(oracleOwner), _toWithdraw);
        assertEq(withdrawed, _toWithdraw);
    }

    /// @notice Test withdraw cancel sub mid cycle then withdraw with sub change
    /// @dev Should not revert
    function testOracleControllerCancelMidCycleThenWithdrawFeeChange(address _payer, address _sub, uint128 _blocks, uint128 _cancelBlock, uint256 _newFee) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 10);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_cancelBlock > 11);
        evm.assume(_cancelBlock < _blocks);
        evm.assume(_newFee != subscriptionFee);

        uint256 endingBlock = block.number + _blocks;
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);

        assert(oracleController.getIsSubscribed(_sub));

        evm.prank(oracleOwner);
        oracleController.setSubscriptionFee(_newFee);

        evm.roll(_cancelBlock);
        uint256 _toReturn = (endingBlock - block.number) * subscriptionFee;
        uint256 _toWithdraw = subAmount - _toReturn;

        evm.prank(_payer);
        oracleController.cancelSubscription(_sub);

        assertEq(erc20Token.balanceOf(_payer), _toReturn);

        evm.prank(oracleOwner);
        uint256 withdrawed = oracleController.withdrawTokens();

        assertEq(erc20Token.balanceOf(oracleOwner), _toWithdraw);
        assertEq(withdrawed, _toWithdraw);
    }
}
