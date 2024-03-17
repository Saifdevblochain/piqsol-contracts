// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

// import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract PQLtoken is
    Initializable,
    ContextUpgradeable,
    IERC20,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // @custom:oz-upgrades-unsafe-allow constructora
    // constructor() {
    //     _disableInitializers();
    // }

    // using SafeMathUpgradeable for uint256;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowed;

    mapping(address => bool) users;
    address[] public tokenHolderAddresses;
    uint256 public taxFee; // this variable holding tax amount
    address public toLiquidityPool;
    address private taxSender;
    uint256 private perTokenValue;
    address public ownerAddress;
    uint256 public deployedTime;
    uint256 public taxDeductionPeriod;
    mapping(address => bool) public whitelisted;

    /*===========Events================-*/
    event transferTokens(address from, address to, uint256 amount);
    event rewardDistribution(address from, address to, uint256 amount);

    function initialize(
        address _toLiquidityPool,
        uint _supply
    ) public initializer {
        toLiquidityPool = _toLiquidityPool;
        name = "piqsol";
        symbol = "PQL";
        decimals = 18;
        totalSupply = _supply;
        ownerAddress = msg.sender;
        balances[ownerAddress] = totalSupply;
        tokenHolderAddresses.push(ownerAddress);
        users[ownerAddress] = true;
        deployedTime = block.timestamp;

        taxDeductionPeriod = 30 days;

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function mintMoreTokens(uint256 _mintAmount) public onlyOwner {
        balances[ownerAddress] += _mintAmount;
        totalSupply += _mintAmount;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return balances[_owner];
    }

    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256) {
        return allowed[_owner][_spender];
    }

    function setLiquidityPoolAddress(address _poolAddress) public onlyOwner {
        toLiquidityPool = _poolAddress;
    }

    function whitelistUser(address _user) public onlyOwner {
        whitelisted[_user] = true;
    }

    function removeWhitelistUser(address _user) public onlyOwner {
        whitelisted[_user] = false;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            allowed[msg.sender][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external virtual returns (bool) {
        uint256 currentAllowance = allowed[msg.sender][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        return true;
    }

    function transfer(
        address recipient,
        uint256 amount
    )
        public
        override
        canTransfer(_msgSender(), recipient, amount)
        returns (bool)
    {
        if (whitelisted[msg.sender] == true || whitelisted[recipient] == true) {
            _transferTokenBalances(msg.sender, recipient, amount);
        } else {
            _transfer(_msgSender(), recipient, amount);
        }
        return true;
    }

    // transfer the tokens to the buyers after tax deduction
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override canTransfer(sender, recipient, amount) returns (bool) {
        require(
            allowed[sender][msg.sender] >= amount,
            "BEP20: amount not approved"
        );
        allowed[sender][msg.sender] = allowed[sender][msg.sender] - (amount);
        if (whitelisted[sender] == true || whitelisted[recipient] == true) {
            _transferTokenBalances(sender, recipient, amount);
        } else {
            _transfer(sender, recipient, amount);
        }
        return true;
    }

    // shows the list of all users
    function getListOfTokenAddress() public view returns (address[] memory) {
        return tokenHolderAddresses;
    }

    // transfer the tokens after calculations of tax fee
    function _transfer(address from, address to, uint256 amount) private {
        if (block.timestamp - deployedTime >= taxDeductionPeriod) {
            if (!users[to]) {
                users[to] = true;
                tokenHolderAddresses.push(to);
            }
            _transferTokenBalances(from, to, amount);
            emit Transfer(from, to, amount);
        } else {
            uint256 userApplicableAmount = calculateTax(amount, 75);
            taxFee = calculateTax(amount, 25);
            _transferTokenBalances(from, to, userApplicableAmount);

            if (!users[to]) {
                users[to] = true;
                tokenHolderAddresses.push(to);
                taxSender = from;
                sendTexfeeTollAll();
            }
            emit Transfer(from, to, userApplicableAmount);
        }
    }

    function setTaxDeductionPeriod(uint256 _time) public onlyOwner {
        taxDeductionPeriod = _time;
    }

    function sendRewardToTokenHolders() private {
        for (uint256 i = 0; i < tokenHolderAddresses.length; i++) {
            perTokenValue =
                (balances[tokenHolderAddresses[i]] *
                    (calculateTax(taxFee, 50))) /
                totalSupply;
            _transferTokenBalances(
                taxSender,
                tokenHolderAddresses[i],
                perTokenValue
            );
            emit rewardDistribution(
                taxSender,
                tokenHolderAddresses[i],
                perTokenValue
            );
        }
    }

    function _transferTokenBalances(
        address from,
        address to,
        uint256 amount
    ) private {
        balances[from] = balances[from] - (amount);
        balances[to] = balances[to] + (amount);
    }

    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        allowed[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function calculateTax(
        uint256 _amount,
        uint256 _tax
    ) public pure returns (uint256) {
        return (_amount * _tax) / 100;
    }

    function sendTexfeeTollAll() private {
        _transferTokenBalances(
            taxSender,
            ownerAddress,
            calculateTax(taxFee, 25)
        );
        _transferTokenBalances(
            taxSender,
            toLiquidityPool,
            calculateTax(taxFee, 25)
        );
        sendRewardToTokenHolders();
    }

    modifier canTransfer(
        address from,
        address to,
        uint256 amount
    ) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        require(
            balances[from] >= amount,
            "BEP20: user balance is insufficient"
        );
        require(amount > 0, "BEP20: amount can not be zero");
        _;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
