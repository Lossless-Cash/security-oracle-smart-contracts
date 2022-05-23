// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./utils/LosslessDevEnvironment.t.sol";


contract TornadoTransactionMockerTests is LosslessDevEnvironment {

    function testTornadoWithdrawal(address _withdrawer) public {
        evm.assume(_withdrawer != mockerOwner);
        evm.assume(_withdrawer != address(0));
        evm.prank(_withdrawer);
        tornadoMocker.Withdraw();

        assertEq(tornadoMocker.balanceOf(_withdrawer), mockerNetWithdraw);
    }

    function testTornadoRefill(address _withdrawer) public {
        evm.assume(_withdrawer != mockerOwner);
        evm.assume(_withdrawer != address(0));

        evm.startPrank(_withdrawer);
        for (uint i; i < 99; i++) {
            tornadoMocker.Withdraw();
        }
        evm.stopPrank();

        evm.prank(mockerOwner);
        tornadoMocker.refill();

        assertEq(tornadoMocker.balanceOf(address(tornadoMocker)), tornadoMocker.initialSupply());
    }
}