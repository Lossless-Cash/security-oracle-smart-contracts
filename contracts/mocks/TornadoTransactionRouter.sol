// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';

interface Mocker {
    function transferFunds(address _receiver) external;
}

contract TornadoTransactionRouter is Ownable{

    Mocker public mocker;

    event Transfered(address _receiver);

    constructor (Mocker _mocker) {
        mocker = _mocker;
    }

    function withdraw() public {
        mocker.transferFunds(msg.sender);
        emit Transfered(msg.sender);
    }
}