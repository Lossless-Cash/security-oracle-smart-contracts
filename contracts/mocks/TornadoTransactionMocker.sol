// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';

contract TornadoTransactionMocker is Ownable{

    uint256 public initialSupply;
    uint256 public currentSupply;
    uint256 public decimals;

    uint256 public denomination;
    uint256 public fee;

    string public name;
    string public symbol;

    mapping(address => uint256) public balances;

    event Withdrawal(address _receiver, bytes32 _emtpy, address a, uint256 b);

    constructor (string memory _name, string memory _symbol, uint256 _denomination, uint256 _fee) {
        decimals = 18;
        Ownable.transferOwnership(_msgSender());
        initialSupply = type(uint256).max;
        balances[address(this)] = initialSupply;
        currentSupply = initialSupply;
        name = _name;
        symbol = _symbol;
        denomination = _denomination;
        fee = _fee;
    }

    function refill() public onlyOwner() {
        balances[address(this)] = initialSupply;
    }

    function setFee(uint256 _fee) public onlyOwner() {
        fee = _fee;
    }

    function setDenomination(uint256 _amount) public onlyOwner() {
        require(_amount == 1 || _amount % 10 == 0, 'must be one or divisible by ten');
        fee = _amount;
    }

    function balanceOf(address _address) public view returns(uint256) {
        return balances[_address];
    }

    function Withdraw() public {
        uint256 _fee = denomination * fee / 100;
        uint256 _amountToTransfer = denomination - _fee;

        balances[address(this)] -= _amountToTransfer;
        currentSupply -= _amountToTransfer;
        balances[_msgSender()] += _amountToTransfer;

        emit Withdrawal(_msgSender(), '', address(this), _fee);
    }
}