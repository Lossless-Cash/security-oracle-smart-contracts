// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import "../../LosslessSecurityOracle.sol";
import "../../LosslessOracleController.sol";
import "../../utils/ERC20.sol";

import "./IEvm.sol";
import "ds-test/test.sol";

contract LosslessDevEnvironment is DSTest {

    Evm public evm = Evm(HEVM_ADDRESS);

    LosslessSecurityOracle public securityOracle;
    LosslessOracleController public oracleController;
    
    ERC20 public erc20Token;

    address public securityOwner = address(1);
    address public oracleOwner = address(2);
    address public erc20Admin = address(3);

    uint256 public subscriptionFee = 1;

    uint256 public totalSupply = type(uint256).max;

    function setUp() public {
        oracleController = new LosslessOracleController();
        securityOracle = new LosslessSecurityOracle();

        evm.prank(erc20Admin);
        erc20Token = new ERC20(
            "ERC20 Token",
            "ERC20",
            totalSupply
        );

        setUpOracleController();
        setUpSecurityOracle();
    }

    /// ----- Helpers ------


    /// @notice Discard test where fuzzing address equals owner
    modifier notOwner(address _impersonator) {
        evm.assume(_impersonator != oracleOwner);
        _;
    }

    /// @notice Discard test where fuzzing address equals zero address
    modifier notZero(address _address) {
        evm.assume(_address != address(0));
        _;
    }

    /// @notice Sets up Lossless Oracle Controller
    function setUpOracleController() public {
        evm.startPrank(oracleOwner);
        oracleController.initialize(subscriptionFee, erc20Token);
        oracleController.setSecurityOracle(securityOracle);
        evm.stopPrank();
    }

    /// @notice Sets up Lossless Security Oracle
    function setUpSecurityOracle() public {
        evm.startPrank(securityOwner);
        securityOracle.initialize(oracleController);
        evm.stopPrank();
    }

    /// @notice Generates a subscription
    function generateSubscription(address _payer, address _sub, uint128 _blocks) public returns(uint256){
        uint256 subAmount = _blocks * subscriptionFee;
        
        evm.prank(erc20Admin);
        erc20Token.transfer(_payer, subAmount);

        evm.startPrank(_payer);
        erc20Token.approve(address(oracleController), subAmount);

        if (_sub == address(0)) {
            evm.expectRevert("LSS: Cannot sub zero address");
        } 
        oracleController.subscribe(_sub, _blocks);      
        
        evm.stopPrank();  

        return subAmount;
    }
}