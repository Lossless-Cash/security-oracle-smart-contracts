// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./utils/LosslessDevEnvironment.t.sol";
import "../interfaces/ILosslessSecurityOracle.sol";

contract LosslessSecurityOracleTests is LosslessDevEnvironment {

    mapping(address => uint8) public riskScores;

    modifier zeroFee(){
        evm.prank(securityOwner);
        subscriptionFee = 0;
        securityOracle.setSubscriptionFee(subscriptionFee);
        _;
    }

    /// @notice Generate risk scores and sub
    function setUpStartingPoint(address _payer, address _sub, uint128 _blocks, RiskScores[] calldata newScores, bool _subbed) public {
        // Set risk scores
        evm.assume(_blocks > 100);
        evm.startPrank(oracle);
        securityOracle.setRiskScores(newScores);
        evm.stopPrank();

        if (_subbed) {
            generateSubscription(_payer, _sub, _blocks);
            assert(securityOracle.getIsSubscribed(_sub));
        }
    }

    /// @notice Test getting risk scores with subscription
    /// @notice should not revert
    function testSecurityOracleGetRiskSubActive(address _payer, address _sub, uint128 _blocks, RiskScores[] calldata newScores, uint256 _getScore) public notZero(_payer) notZero(_sub) {
        evm.assume(newScores.length > 0);
        evm.assume(_blocks > 100);
        evm.assume(_blocks < type(uint128).max - 100);
        
        setUpStartingPoint(_payer, _sub, _blocks, newScores, true);

        for (uint i; i < newScores.length; i++) {
            riskScores[newScores[i].addr] = newScores[i].score;
        }

        evm.roll(5);
        evm.startPrank(_sub);

        for (uint i; i < newScores.length; i++) {
            address addressToCheck = newScores[i].addr;
            uint8 riskScore = securityOracle.getRiskScore(addressToCheck);

            assertEq(riskScore, riskScores[addressToCheck]);
        }
        evm.stopPrank();
    }

    /// @notice Test getting risk scores subscription expired
    /// @notice should not revert but return 0
    function testSecurityOracleGetRiskSubExpired(address _payer, address _sub, uint128 _blocks, RiskScores[] calldata newScores, uint256 _getScore) public notZero(_payer) notZero(_sub) {
        
        evm.assume(_blocks > 100);
        evm.assume(_blocks < type(uint128).max - 100);
        
        setUpStartingPoint(_payer, _sub, _blocks, newScores, true);
        
        evm.roll(_blocks + 1);
        evm.startPrank(_sub);

        for (uint i; i < newScores.length; i++) {
            uint8 riskScore = securityOracle.getRiskScore(newScores[i].addr);

            assertEq(riskScore, 0);
        }
        evm.stopPrank();
    }


    /// @notice Test adding oracle
    /// @notice should not revert
    function testSecurityOracleAddOracle(address _newOracle) public {
        evm.assume(_newOracle != oracle);
        evm.prank(securityOwner);
        securityOracle.addOracle(_newOracle);
    }

    /// @notice Test adding oracle same address
    /// @notice should revert
    function testSecurityOracleAddOracleSameAddress() public {
        evm.prank(securityOwner);
        evm.expectRevert("LSS: Cannot set same address");
        securityOracle.addOracle(oracle);
    }

    /// @notice Test removing oracle
    /// @notice should not revert
    function testSecurityOracleRemoveOracle() public {
        evm.prank(securityOwner);
        securityOracle.removeOracle(oracle);
    }

    /// @notice Test removing non existing
    /// @notice should revert
    function testSecurityOracleRemoveOracleNonExisting(address _newOracle) public {
        evm.assume(_newOracle != oracle);
        evm.prank(securityOwner);
        evm.expectRevert("LSS: Not Oracle");
        securityOracle.removeOracle(_newOracle);
    }

    /// @notice Test adding oracle by non owner
    /// @notice should revert
    function testSecurityOracleAddOracleNonOwner(address _impersonator, address _newOracle) public notOwner(_impersonator) {
        evm.assume(_newOracle != oracle);
        evm.prank(_impersonator);
        evm.expectRevert("Ownable: caller is not the owner");
        securityOracle.addOracle(_newOracle);
    }

    /// @notice Test removing oracle by non owner
    /// @notice should revert
    function testSecurityOracleRemoveOracleNonOwner(address _impersonator) public notOwner(_impersonator) {
        evm.prank(_impersonator);
        evm.expectRevert("Ownable: caller is not the owner");
        securityOracle.removeOracle(oracle);
    }

    /// @notice Test getting risk scores without subscription
    /// @notice should revert
    function testSecurityOracleGetRiskSubNone(address _payer, address _sub, uint128 _blocks, RiskScores[] calldata newScores, uint256 _getScore) public notZero(_payer) notZero(_sub) {
        
        evm.assume(_blocks > 100);
        evm.assume(_blocks < type(uint128).max - 100);
        
        setUpStartingPoint(_payer, _sub, _blocks, newScores, false);
        
        evm.roll(5);
        evm.startPrank(_sub);
        
        for (uint i; i < newScores.length; i++) {
            uint8 riskScore = securityOracle.getRiskScore(newScores[i].addr);

            assertEq(riskScore, 0);
        }
        evm.stopPrank();
    }

    /// @notice Test Subscription Fee Set up
    /// @dev Should not revert
    function testSecurityOraclerSetSubscriptionFee(uint256 _newFee) public {
        evm.startPrank(securityOwner);
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
        evm.assume(_blocks > 100);
        generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));
    }

    /// @notice Test set risk scores
    /// @dev Should not revert
    function testSecurityOraclerSetRiskScores(RiskScores[] calldata newScores) public zeroFee() {

        evm.startPrank(oracle);
        securityOracle.setRiskScores(newScores);

        evm.stopPrank();
    }

    /// @notice Test set risk scores non oracle
    /// @dev Should revert
    function testSecurityOraclerSetRiskScoresNonOracle(RiskScores[] calldata newScores) public {
        evm.startPrank(address(9999));
        evm.expectRevert("LSS: Only Oracle Controller");
        securityOracle.setRiskScores(newScores);
        evm.stopPrank();
    }

    /// @notice Test withdraw one full cycle
    /// @dev Should not revert
    function testSecurityOraclerWithdraw(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub) notOwner(_payer){

        evm.assume(_blocks > 100);
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

        evm.assume(_blocks > 100);
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
        evm.assume(_blocks > 100);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 100);
        evm.assume(_extension < type(uint128).max - 100);
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks + 1);
        assert(!securityOracle.getIsSubscribed(_sub));

        extendSubscription(_payer, _sub, _extension);

        assert(securityOracle.getIsSubscribed(_sub));
    }

    /// @notice Test subscription extension by anyone
    /// @dev Should not revert
    function testSecurityOracleExtendSubByAnyone(address _payer, address _sub, uint128 _blocks, uint128 _extension, address _extender) public notZero(_extender) notZero(_payer) notZero(_sub) notOwner(_payer){
        evm.assume(_extender != _payer);
        evm.assume(_blocks > 100);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 100);
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
        evm.assume(_blocks > 100);
        evm.assume(_blocks < type(uint128).max / 2 - 100);
        evm.assume(_extension > 100);
        evm.assume(_extension < type(uint128).max / 2 - 100);
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
    
    /// @notice Test withdraw before and after extension
    /// @dev Should not revert
    function testSecurityOracleExtendSubWithdrawing(address _payer, address _sub, uint128 _blocks, uint128 _extension) public notZero(_payer) notZero(_sub) notOwner(_payer){
        evm.assume(_blocks > 100);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 100);
        evm.assume(_extension < type(uint128).max - 100);

        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.prank(securityOwner);
        uint256 withdrawed = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), subAmount);
        assertEq(withdrawed, subAmount);

        evm.roll(_blocks + 1);
        assert(!securityOracle.getIsSubscribed(_sub));

        uint256 extendAmount = generateSubscription(_payer, _sub, _extension);
        
        evm.prank(securityOwner);
        uint256 withdrawedExt = securityOracle.withdrawTokens();

        assertEq(erc20Token.balanceOf(securityOwner), subAmount + extendAmount);
        assertEq(withdrawedExt, extendAmount);
    }

    /// @notice Test withdraw before and after extension with fee change
    /// @dev Should not revert
    function testSecurityOracleExtendSubWithdrawing(address _payer, address _sub, uint128 _blocks, uint128 _extension, uint128 _newFee) public notZero(_payer) notZero(_sub) notOwner(_payer){
        evm.assume(_blocks > 100);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 100);
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

    /// @notice Test subscription with zero fee
    /// @dev Should not revert
    function testSecurityOraclerSubscriptionZeroFee(address _payer, address _sub, uint128 _blocks) public notZero(_payer) notZero(_sub) zeroFee() {
        evm.assume(_blocks > 100);
        generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));
    }


    /// @notice Test subscription extension with zero fee
    /// @dev Should not revert
    function testSecurityOracleExtendSubZeroFee(address _payer, address _sub, uint128 _blocks, uint128 _extension) public notZero(_payer) notZero(_sub) notOwner(_payer) zeroFee() {
        evm.assume(_blocks > 100);
        evm.assume(_blocks < type(uint128).max - 100);
        evm.assume(_extension > 100);
        evm.assume(_extension < type(uint128).max - 100);
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks + 1);
        assert(securityOracle.getIsSubscribed(_sub));

        extendSubscription(_payer, _sub, _extension);

        assert(securityOracle.getIsSubscribed(_sub));
    }

    /// @notice Test subscription extension by anyone with zero fee
    /// @dev Should not revert
    function testSecurityOracleExtendSubByAnyoneZeroFee(address _payer, address _sub, uint128 _blocks, uint128 _extension, address _extender) public notZero(_extender) notZero(_payer) notZero(_sub) notOwner(_payer) zeroFee() {
        evm.assume(_extender != _payer);
        evm.assume(_blocks > 100);
        evm.assume(_blocks < type(uint128).max / 2  - 100);
        evm.assume(_extension > 100);
        evm.assume(_extension < type(uint128).max / 2 - 100);
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks + 1);
        assert(securityOracle.getIsSubscribed(_sub));

        extendSubscription(_extender, _sub, _extension);

        assert(securityOracle.getIsSubscribed(_sub));
    }

    /// @notice Test subscription extension multiple times with zero fee
    /// @dev Should not revert
    function testSecurityOracleExtendSubMultipleZeroFee(address _payer, address _sub, uint128 _blocks, uint128 _extension) public notZero(_payer) notZero(_sub) notOwner(_payer) zeroFee() {
        evm.assume(_blocks > 100);
        evm.assume(_blocks < type(uint128).max / 2 - 100);
        evm.assume(_extension > 100);
        evm.assume(_extension < type(uint128).max / 2 - 100);
        uint256 subAmount = generateSubscription(_payer, _sub, _blocks);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks + 1);
        assert(securityOracle.getIsSubscribed(_sub));

        extendSubscription(_payer, _sub, _extension);
        assert(securityOracle.getIsSubscribed(_sub));

        evm.roll(_blocks + _extension + 100);
        extendSubscription(_payer, _sub, _extension);
        assert(securityOracle.getIsSubscribed(_sub));
    }
}
