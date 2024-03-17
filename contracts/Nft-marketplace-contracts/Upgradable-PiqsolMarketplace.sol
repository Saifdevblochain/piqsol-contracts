// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract PiqsolMarketplace is
    Initializable,
    ERC721HolderUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    //** Tax Listing **//
    uint256 listingTax;
    uint256 buyitemTax;
    uint256 biditemTax;
    ERC20Upgradeable public Token;
    address public marketPlaceOwner;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _marketplaceOwner,
        address PQLTokenAddress,
        uint256 _listingTax,
        uint256 _buyitemTax,
        uint256 _biditemTax
    ) public initializer {
        marketPlaceOwner = _marketplaceOwner;
        Token = ERC20Upgradeable(PQLTokenAddress);
        setServiceFee(_listingTax, _buyitemTax, _biditemTax);
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // using SafeMathUpgradeable for uint256;
    //** auction Listing **//
    struct AuctionListItem {
        uint256 id;
        address tokenAddress;
        uint256 tokenId;
        address[] royaltiesRecipientAddress;
        uint256[] percentageBasisPoints;
        address payable beneficiary;
        uint256 minPrice;
        bool OpenForBidding;
        uint256 auctionEndTime;
        address highestBidder;
        uint256 highestBid;
        bool isSold;
    }

    AuctionListItem[] public AuctionItemsForSale;
    mapping(address => mapping(uint256 => bool)) AuctionActiveItems;

    //** Fixed Price List items **//
    struct FixedPriceListItem {
        uint256 id;
        address tokenAddress;
        uint256 tokenId;
        address[] royaltiesRecipientAddress;
        uint256[] percentageBasisPoints;
        address payable seller;
        uint256 askingPrice;
        bool listing;
        bool isSold;
    }

    FixedPriceListItem[] public FixedItemsForSale;
    mapping(address => mapping(uint256 => bool)) FixedPriceActiveItems;

    event itemAdded(
        uint256 id,
        uint256 tokenId,
        address tokenAddress,
        uint256 askingPrice
    );
    event itemSold(uint256 id, address buyer, uint256 askingPrice);
    event HighestBidIcrease(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    modifier OnlyItemOwner(address tokenAddress, uint256 tokenId) {
        IERC721 tokenContract = IERC721(tokenAddress);
        require(
            tokenContract.ownerOf(tokenId) == msg.sender,
            "Piqsol:only owner"
        );
        _;
    }

    modifier HasTransferApproval(address tokenAddress, uint256 tokenId) {
        IERC721 tokenContract = IERC721(tokenAddress);
        require(
            tokenContract.getApproved(tokenId) == address(this),
            "Piqsol:approvel"
        );
        _;
    }

    modifier FixedItemExists(uint256 id) {
        require(
            id < FixedItemsForSale.length && FixedItemsForSale[id].id == id,
            "Piqsol:Could not find Item"
        );
        _;
    }

    modifier FixedIsForSale(uint256 id) {
        require(
            FixedItemsForSale[id].isSold == false,
            "Piqsol: Fixed Price Item is already sold"
        );
        _;
    }
    modifier AuctionItemExists(uint256 id) {
        require(
            id < AuctionItemsForSale.length && AuctionItemsForSale[id].id == id,
            "Piqsol:Could not find Item"
        );
        _;
    }

    function listFixedItemToMarket(
        uint256 tokenId,
        address tokenAddress,
        uint256 askingPrice,
        address[] calldata _royaltiesRecipientAddress,
        uint256[] calldata _percentageBasisPoints
    ) external HasTransferApproval(tokenAddress, tokenId) returns (uint256) {
        require(
            IERC721(tokenAddress).ownerOf(tokenId) == msg.sender,
            "only owner can call this method"
        );
        require(
            FixedPriceActiveItems[tokenAddress][tokenId] == false,
            "Piqsol:Item is already up for Sale"
        );
        require(askingPrice > 0, "PIQSOL: price must be greater than zero.");
        uint256 newItemId = FixedItemsForSale.length;
        FixedItemsForSale.push(
            FixedPriceListItem(
                newItemId,
                tokenAddress,
                tokenId,
                _royaltiesRecipientAddress,
                _percentageBasisPoints,
                payable(msg.sender),
                askingPrice,
                true,
                false
            )
        );
        FixedPriceActiveItems[tokenAddress][tokenId] = true;
        //** taxation **//
        tax_deduction(msg.sender, listingTax);
        IERC721(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        assert(FixedItemsForSale[newItemId].id == newItemId);
        emit itemAdded(newItemId, tokenId, tokenAddress, askingPrice);
        return newItemId;
    }

    function canclelistOfFixedItem(uint256 id) external FixedItemExists(id) {
        require(
            msg.sender == FixedItemsForSale[id].seller,
            "Piqsol:Only seller can call this method"
        );
        require(FixedItemsForSale[id].isSold == false, "Piqsol:Already sold");
        FixedPriceActiveItems[FixedItemsForSale[id].tokenAddress][
            FixedItemsForSale[id].tokenId
        ] = false;
        IERC721(FixedItemsForSale[id].tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            FixedItemsForSale[id].tokenId
        );
        FixedItemsForSale[id].listing = false;
    }

    function buyItem(
        uint256 id
    ) external payable FixedItemExists(id) FixedIsForSale(id) {
        require(FixedItemsForSale[id].listing == true, "Piqsol:Can't buy");
        require(
            msg.value == FixedItemsForSale[id].askingPrice,
            "Piqsol:Not enough funds sent"
        );
        require(
            msg.sender != FixedItemsForSale[id].seller,
            "Piqsol:Owner can't buy"
        );
        address[] memory _royaltiesRecipientAddress = FixedItemsForSale[id]
            .royaltiesRecipientAddress;
        FixedItemsForSale[id].isSold = true;
        FixedPriceActiveItems[FixedItemsForSale[id].tokenAddress][
            FixedItemsForSale[id].tokenId
        ] = false;

        for (uint256 i; i < _royaltiesRecipientAddress.length; i++) {
            if (_royaltiesRecipientAddress[i] != address(0)) {
                uint256 royalityFee = calculateRoyaltyFee(
                    FixedItemsForSale[id].askingPrice,
                    FixedItemsForSale[id].percentageBasisPoints[i]
                );
                uint256 finalAmount = (FixedItemsForSale[id].askingPrice) -
                    (royalityFee);
                FixedItemsForSale[id].seller.transfer(finalAmount);
                // ** taxation **//
                tax_deduction(msg.sender, buyitemTax);
                payable(_royaltiesRecipientAddress[i]).transfer(royalityFee);
            } else {
                FixedItemsForSale[id].seller.transfer(
                    FixedItemsForSale[id].askingPrice
                );
                // ** taxation **//
                tax_deduction(msg.sender, buyitemTax);
            }
        }
        IERC721(FixedItemsForSale[id].tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            FixedItemsForSale[id].tokenId
        );
        emit itemSold(id, msg.sender, FixedItemsForSale[id].askingPrice);
    }

    // ******Add auction items ******//
    function listAuctionItemToMarket(
        uint256 tokenId,
        address tokenAddress,
        uint256 _minPrice,
        uint256 _auctionEndTime,
        address[] calldata _royaltiesRecipientAddress,
        uint256[] calldata _percentageBasisPoints
    ) external HasTransferApproval(tokenAddress, tokenId) returns (uint256) {
        require(
            AuctionActiveItems[tokenAddress][tokenId] == false,
            "Piqsol:Item is already up for Sale"
        );
        require(
            IERC721(tokenAddress).ownerOf(tokenId) == msg.sender,
            "Piqsol:only owner can call this method"
        );
        require(_minPrice > 0, "PIQSOL: price must be greater than zero.");
        uint256 newItemId = AuctionItemsForSale.length;
        AuctionItemsForSale.push(
            AuctionListItem(
                newItemId,
                tokenAddress,
                tokenId,
                _royaltiesRecipientAddress,
                _percentageBasisPoints,
                payable(msg.sender),
                _minPrice,
                true,
                block.timestamp + _auctionEndTime,
                address(0),
                0,
                false
            )
        );
        AuctionActiveItems[tokenAddress][tokenId] = true;
        // taxation **//
        tax_deduction(msg.sender, listingTax);
        IERC721(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        assert(AuctionItemsForSale[newItemId].id == newItemId);
        emit itemAdded(newItemId, tokenId, tokenAddress, _minPrice);
        return newItemId;
    }

    function canclelistOfAuctionItem(
        uint256 id
    ) external AuctionItemExists(id) {
        require(
            msg.sender == AuctionItemsForSale[id].beneficiary,
            "Piqsol:Only seller can call this method"
        );
        require(
            AuctionItemsForSale[id].highestBidder == address(0),
            "Piqsol:Already bid"
        );
        AuctionActiveItems[AuctionItemsForSale[id].tokenAddress][
            AuctionItemsForSale[id].tokenId
        ] = false;
        IERC721(AuctionItemsForSale[id].tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            AuctionItemsForSale[id].tokenId
        );
    }

    function bid(uint256 id) public payable AuctionItemExists(id) {
        require(
            AuctionItemsForSale[id].OpenForBidding,
            "Piqsol:Bidding is not open yet"
        );
        require(
            msg.sender != AuctionItemsForSale[id].beneficiary,
            "Piqsol:Owner can't bid"
        );
        address currentBidOwner = AuctionItemsForSale[id].highestBidder;
        uint256 currentBidAmount = AuctionItemsForSale[id].highestBid;

        if (block.timestamp > AuctionItemsForSale[id].auctionEndTime) {
            revert("Piqsol:The auction has already ended");
        }
        if (msg.value <= AuctionItemsForSale[id].minPrice) {
            revert("Piqsol:can't Bid ,Amount too low");
        }
        if (msg.value <= currentBidAmount) {
            revert("Piqsol:There is already higher or equal bid exist");
        }
        if (msg.value > currentBidAmount) {
            payable(currentBidOwner).transfer(currentBidAmount);
        }
        // taxation **//
        tax_deduction(msg.sender, biditemTax);
        AuctionItemsForSale[id].highestBidder = msg.sender;
        AuctionItemsForSale[id].highestBid = msg.value;
        emit HighestBidIcrease(msg.sender, msg.value);
    }

    function auctionEnd(uint256 id) public {
        require(
            AuctionItemsForSale[id].OpenForBidding,
            "Piqsol:Bidding is not open yet"
        );
        require(
            block.timestamp > AuctionItemsForSale[id].auctionEndTime,
            "Piqsol:The auction has not ended yet"
        );
        require(
            msg.sender == AuctionItemsForSale[id].highestBidder,
            "Piqsol:Only highest bidder can call this method"
        );
        address[] memory _royaltiesRecipientAddress = AuctionItemsForSale[id]
            .royaltiesRecipientAddress;
        AuctionItemsForSale[id].isSold = true;
        AuctionActiveItems[AuctionItemsForSale[id].tokenAddress][
            AuctionItemsForSale[id].tokenId
        ] = false;
        for (uint256 i; i < _royaltiesRecipientAddress.length; i++) {
            if (_royaltiesRecipientAddress[i] != address(0)) {
                uint256 royalityFee = calculateRoyaltyFee(
                    AuctionItemsForSale[id].highestBid,
                    AuctionItemsForSale[id].percentageBasisPoints[i]
                );
                uint256 finalAmount = (AuctionItemsForSale[id].highestBid) -
                    (royalityFee);
                AuctionItemsForSale[id].beneficiary.transfer(finalAmount);
                payable(_royaltiesRecipientAddress[i]).transfer(royalityFee);
            } else {
                AuctionItemsForSale[id].beneficiary.transfer(
                    AuctionItemsForSale[id].highestBid
                );
            }
        }

        IERC721(AuctionItemsForSale[id].tokenAddress).safeTransferFrom(
            address(this),
            AuctionItemsForSale[id].highestBidder,
            AuctionItemsForSale[id].tokenId
        );
        emit AuctionEnded(
            AuctionItemsForSale[id].highestBidder,
            AuctionItemsForSale[id].highestBid
        );
    }

    function setServiceFee(
        uint256 _listingTax,
        uint256 _buyitemTax,
        uint256 _biditemTax
    ) public {
        require(
            marketPlaceOwner == msg.sender,
            "Piqsol:Only Marketplace Owner can call this method"
        );
        listingTax = _listingTax;
        buyitemTax = _buyitemTax;
        biditemTax = _biditemTax;
    }

    // ** Calculate royalty fee **//
    function calculateRoyaltyFee(
        uint256 _salePrice,
        uint256 _percentageBasisPoints
    ) internal pure returns (uint256) {
        require(
            _percentageBasisPoints <= 10000,
            "ERC2981: royalty fee will exceed salePrice"
        );
        uint256 royalityfee = (_salePrice * _percentageBasisPoints) / 10000;
        return royalityfee;
    }

    function check_balance(address user) internal view returns (uint256) {
        uint256 bal = Token.balanceOf(user);
        return bal;
    }

    //***** calculate Tax ****///
    function tax_deduction(address _user, uint256 _serviceFee) internal {
        if (_serviceFee != 0) {
            uint256 current_bal = check_balance(_user);
            require(
                current_bal >= _serviceFee,
                "Piqsol:don't have enough tokens to pay tax"
            );
            Token.transferFrom(_user, marketPlaceOwner, _serviceFee);
        }
    }
}
