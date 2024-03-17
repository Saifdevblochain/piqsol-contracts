// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IBEP20 {
    function balanceOf(address account) external view returns (uint256);
}

contract DexSell is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    ERC20Upgradeable public PqlToken;
    address public owners;
    uint256 public tokenPerEth;

    function initialize(address PQLTokenAddress) public initializer {
        tokenPerEth = 100;
        owners = msg.sender;
        PqlToken = ERC20Upgradeable(PQLTokenAddress);
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /*===========Events================-*/
    event buy(address from, address reciever, uint256 amount);
    event tokenRate(uint256 rate);

    // set the per token price
    function setTokenPerEthPrice(uint256 _tokenPerEthPrice) public onlyOwner {
        tokenPerEth = _tokenPerEthPrice;
        emit tokenRate(_tokenPerEthPrice);
    }

    // check the balance of user
    function userTokenBalance() public view returns (uint256) {
        return PqlToken.balanceOf(msg.sender);
    }

    // check the balance of contract
    function contractTokenBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // buy the tokens in exchange of ethers
    function Buy() external payable nonReentrant {
        uint256 tokensAmountToBuy = msg.value * tokenPerEth;
        require(msg.value > 0, "Your Buying must be greater than zero");
        PqlToken.transferFrom(owners, msg.sender, tokensAmountToBuy);

        payable(owners).transfer(msg.value);

        emit buy(owners, msg.sender, tokensAmountToBuy);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
