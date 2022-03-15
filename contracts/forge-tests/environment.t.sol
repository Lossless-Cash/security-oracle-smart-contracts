// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./utils/LosslessDevEnvironment.t.sol";

contract EnvironmentTests is LosslessDevEnvironment {
    
    /// @notice Test deployed Random ERC20 Token
    function testERC20TokenDeploy() public {
        assertEq(erc20Token.totalSupply(), totalSupply);
        assertEq(erc20Token.name(), "ERC20 Token");
        assertEq(erc20Token.symbol(), "ERC20");
        assertEq(erc20Token.owner(), erc20Admin);
    }

    /// @notice Test deployed Security Oracle
    function testSecurityOracleSetUp() public {
        assertEq(securityOwner, securityOracle.owner());
        assertEq(securityOracle.subFee(), subscriptionFee);
        assertEq(address(securityOracle.subToken()), address(erc20Token));
    }
}