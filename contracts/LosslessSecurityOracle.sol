// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/ILosslessSecurityOracle.sol";
import "./LosslessOracleController.sol";

contract LosslessSecurityOracle is ILssSecurityOracle, Initializable, ContextUpgradeable, PausableUpgradeable, OwnableUpgradeable {

    ILssOracleController public lssOracleController;

    mapping(address => uint8) public riskScores;

    function initialize(ILssOracleController _controller) public initializer {
        __Ownable_init();
        setOracleController(_controller);
    }

    modifier onlyOracle() {
        require(msg.sender == address(lssOracleController), "LSS: Only Oracle Controller");
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
    /// @param _controller Lossless Oracle Controller address
    function setOracleController(ILssOracleController _controller) override public onlyOwner {
        require(lssOracleController != _controller, "LSS: Cannot set same address");
        lssOracleController = _controller;
        emit NewOracleController(lssOracleController);
    }

    /// @notice This function sets the risk scorefor an address
    /// @param _addresses Lossless Oracle Controller address
    /// @param _scores Lossless Oracle Controller address
    function setRiskScores(address[] memory _addresses, uint8[] memory _scores) override public onlyOracle {
        uint256 listLen = _addresses.length;

        for(uint256 i = 0; i < listLen;) {
            address updatedAddress = _addresses[i];
            uint8 updatedScore = _scores[i];

            riskScores[updatedAddress] = updatedScore;
            
            emit NewRiskScore(updatedAddress, updatedScore);

            unchecked {i++;}
        }
    }

    // --- GETTERS ---
    /// @notice This function returns the risk score of an address
    /// @param _address address to check
    function getRiskScore(address _address) override public view returns(uint8) {
        if (!lssOracleController.getIsSubscribed(msg.sender)) {
            return 0;
        } else {
            return riskScores[_address];
        }
    }
}
