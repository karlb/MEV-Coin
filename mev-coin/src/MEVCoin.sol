// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MEVCoin is ERC20 {
    mapping(uint256 => bool) private _blockMinted;
    
    event MEVBonus(address indexed recipient, uint256 amount, uint256 blockNumber);
    
    constructor() ERC20("MEV-Coin", "MEV") {}
    
    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        _checkAndMintMEVBonus(to);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        _checkAndMintMEVBonus(to);
        return true;
    }
    
    function _checkAndMintMEVBonus(address recipient) internal {
        uint256 currentBlock = block.number;
        
        if (currentBlock % 100 == 0 && !_blockMinted[currentBlock]) {
            _blockMinted[currentBlock] = true;
            uint256 bonusAmount = 100 * 10**decimals();
            _mint(recipient, bonusAmount);
            emit MEVBonus(recipient, bonusAmount, currentBlock);
        }
    }
    
    function hasBlockBeenMinted(uint256 blockNumber) external view returns (bool) {
        return _blockMinted[blockNumber];
    }
}