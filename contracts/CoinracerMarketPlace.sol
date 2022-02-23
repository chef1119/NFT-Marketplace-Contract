// SPDX-License-Identifier: MIT
pragma solidity ^0.7.5;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
// import "hardhat/console.sol"; //For debugging only

contract CoinracerMarketplace is IERC721Receiver, Ownable {
    using SafeERC20 for IERC20;
    // Name of the marketplace
    string public name;

    // Index of auctions
    uint256 public index = 0;
    uint256 private feeAmount = 0;
    ERC20  coinracer;
    IERC721Enumerable coinracer_nft_factory;// = "0xD20086Ff85bc773f54d16Abce2e5bA0dD616B395";

    // Structure to define auction properties
    struct Auction {
        address creator; // Creator of the Auction
        address currentBidOwner; // Address of the highest bider
        uint256 currentBidPrice; // Current highest bid for the auction
        uint256 endAuction; // Timestamp for the end day&time of the auction
        uint256 bidCount; // Number of bid placed on the auction
        bool isOpen;  // can be saled?
    }

    // Array will all auctions
    // Auction[] private allAuctions;
    mapping(uint256 => Auction) public auctionList; // nftID => Auction
    mapping(uint256 => mapping(address => uint256)) public bidders; //nftId => bidderAddr => craceAmount

    // Public event to notify that a new auction has been created
    event NewAuction(
        uint256 nftId,
        address createdBy,
        address currentBidOwner,
        uint256 currentBidPrice,
        uint256 endAuction,
        uint256 bidCount,
        bool isOpen
    );

    // Public event to notify that a new bid has been placed
    event NewBidOnAuction(uint256 nftId, uint256 newBid);

    // Public event to notif that winner of an
    // auction claim for his reward
    event NFTClaimed(uint256 nftId, address claimedBy);

    // Public event to notify that the creator of
    // an auction claimed for his money
    event TokensClaimed(uint256 nftId, address claimedBy);

    // Public event to notify that an NFT has been refunded to the
    // creator of an auction
    event NFTRefunded(uint256 nftId, address claimedBy);

    // constructor of the contract
    constructor(ERC20 _coinracer, address _nftFactory) {
        coinracer = _coinracer;
        coinracer_nft_factory = IERC721Enumerable(_nftFactory);
    }

    /**
     * Check if a specific address is
     * a contract address
     * @param _addr: address to verify
     */
    function isContract(address _addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    /**
     * Create a new auction of a specific NFT
     * @param _nftId Id of the NFT for sale
     * @param _initialBid Inital bid decided by the creator of the auction
     * @param _endAuction Timestamp with the end date and time of the auction
     */
    function createAuction(
        uint256 _nftId,
        uint256 _initialBid,
        uint256 _endAuction
    ) external returns (uint256) {

        // Check if the endAuction time is valid
        require(_endAuction > block.timestamp, "Invalid end date for auction");

        // Check if the initial bid price is > 0
        require(_initialBid > 0, "Invalid initial bid price");

        // Get NFT collection contract
        // NFTCollection nftCollection = NFTCollection(_addressNFTCollection);

        // Make sure the sender that wants to create a new auction
        // for a specific NFT is the owner of this NFT
        require(
            coinracer_nft_factory.ownerOf(_nftId) == msg.sender,
            "Caller is not the owner of the NFT"
        );

        require(auctionList[_nftId].isOpen != true, "Currently on Auction");

        // // Make sure the owner of the NFT approved that the MarketPlace contract
        // // is allowed to change ownership of the NFT
        require(coinracer_nft_factory.getApproved(_nftId) == address(this), "Require NFT ownership transfer approval");

        // Lock NFT in Marketplace contract
        // coinracer_nft_factory.safeTransferFrom(msg.sender, address(this), _nftId);

        //Casting from address to address payable
        address currentBidOwner = address(0);
        // Create new Auction object
        Auction memory newAuction = Auction({
            creator: msg.sender,
            currentBidOwner: currentBidOwner,
            currentBidPrice: _initialBid,
            endAuction: _endAuction,
            bidCount: 0,
            isOpen: true
        });

        //update list
        // allAuctions.push(newAuction);
        auctionList[_nftId] = newAuction;

        // increment auction sequence
        index++;

        // Trigger event and return index of new auction
        emit NewAuction(
            // index,
            // _addressNFTCollection,
            // _addressPaymentToken,
            _nftId,
            msg.sender,
            currentBidOwner,
            _initialBid,
            _endAuction,
            0,
            true
        );
        return index;
    }

    /**
     * Check if an auction is open
     * @param _nftId Index of the auction
     */
    function isTimePassed(uint256 _nftId) public view returns (bool) {
        Auction storage auction = auctionList[_nftId];
        if (block.timestamp >= auction.endAuction) return true;
        return false;
    }

    /**
     * Place new bid on a specific auction
     * @param _nftId Index of auction
     * @param _newBid New bid price
     */
    function bid(uint256 _nftId, uint256 _newBid)
        external
        returns (bool)
    {
        require(auctionList[_nftId].isOpen == true, "Invalid auction");
        Auction storage auction = auctionList[_nftId];

        // check if auction is still open
        require(!isTimePassed(_nftId), "Auction is not open");

        // check if new bid price is higher than the current one
        require(
            _newBid > auction.currentBidPrice,
            "New bid price must be higher than the current bid"
        );

        // check if new bider is not the owner
        require(
            msg.sender != auction.creator,
            "Creator of the auction cannot place new bid"
        );


        // new bid is better than current bid!

        // transfer token from new bider account to the marketplace account
        // to lock the tokens
            coinracer.transferFrom(msg.sender, address(this), _newBid);
        // new bid is valid so must refund the current bid owner (if there is one!)
        if (auction.bidCount > 0) {
            coinracer.transfer(auction.currentBidOwner, auction.currentBidPrice);
        }
        bidders[_nftId][msg.sender] = _newBid;
        // update auction info
        address newBidOwner = msg.sender;
        auction.currentBidOwner = newBidOwner;
        auction.currentBidPrice = _newBid;
        auction.bidCount++;
        
        // Trigger public event
        emit NewBidOnAuction(_nftId, _newBid);

        return true;
    }

    /**
     * Function used by the winner of an auction
     * to withdraw his NFT.
     * When the NFT is withdrawn, the creator of the
     * auction will receive the payment tokens in his wallet
     * @param _nftId Index of auction
     */
    function claimNFT(uint256 _nftId) external {
        require(auctionList[_nftId].isOpen, "Invalid auction");
        require (coinracer_nft_factory.ownerOf(_nftId)!=msg.sender, "You are already owner of this NFT");
        // Check if the auction is closed
        require(isTimePassed(_nftId), "Auction is still open");

        // Get auction
        Auction storage auction = auctionList[_nftId];

        // Check if the caller is the winner of the auction
        require(
            auction.currentBidOwner == msg.sender,
            "NFT can be claimed only by the current bid owner"
        );

        // Get NFT collection contract
        // NFTCollection nftCollection = NFTCollection(
        //     auction.addressNFTCollection
        // );
        // Transfer NFT from marketplace contract
        // to the winner address
        coinracer_nft_factory.safeTransferFrom(auction.creator, auction.currentBidOwner, _nftId);

        // Transfer locked token from the marketplace
        // contract to the auction creator address
        feeAmount = feeAmount + auction.currentBidPrice * 10 / 100;
        uint256 amount = auction.currentBidPrice * 90 / 100;
        coinracer.transfer(auction.creator, amount);
        auction.isOpen = false;
        emit NFTClaimed(_nftId, msg.sender);
    }

    /**
     * Function used by the creator of an auction
     * to withdraw his tokens when the auction is closed
     * When the Token are withdrawn, the winned of the
     * auction will receive the NFT in his walled
     * @param _nftId Index of the auction
     */
    function claimToken(uint256 _nftId) external {
        require(auctionList[_nftId].isOpen, "Invalid auction"); // XXX Optimize

        // Get auction
        Auction storage auction = auctionList[_nftId];

        // Check if the caller is the creator of the auction
        require(
            auction.creator == msg.sender,
            "Tokens can be claimed only by the creator of the auction"
        );

        // Get NFT Collection contract
        // Transfer NFT from marketplace contract
        // to the winned of the auction
        coinracer_nft_factory.safeTransferFrom(auction.creator, auction.currentBidOwner, _nftId);

        
        // Transfer locked tokens from the market place contract
        // to the wallet of the creator of the auction
        feeAmount = feeAmount + auction.currentBidPrice * 10 / 100;
        uint256 amount = auction.currentBidPrice * 90 / 100;
        coinracer.transfer(auction.creator, amount);
        auction.isOpen = false;
        emit TokensClaimed(_nftId, msg.sender);
    }

        /**
        * Function used by the creator of an auction
        * to get his NFT back in case the auction is closed
        * but there is no bider to make the NFT won't stay locked
        * in the contract
        * @param _nftId Index of the auction
     */
    function refund(uint256 _nftId) external {
        require(auctionList[_nftId].isOpen, "Invalid auction");

        // Check if the auction is closed
        require(isTimePassed(_nftId), "Auction is still open");

        // Get auction
        Auction storage auction = auctionList[_nftId];

        // Check if the caller is the creator of the auction
        require(
            auction.creator == msg.sender,
            "Tokens can be claimed only by the creator of the auction"
        );

        require(
            auction.currentBidOwner == address(0),
            "Existing bider for this auction"
        );
        // Transfer NFT back from marketplace contract
        // to the creator of the auction
        // coinracer_nft_factory.transferFrom(
        //     address(this),
        //     auction.creator,
        //     _nftId
        // );
        auction.isOpen = false;
        emit NFTRefunded(_nftId, msg.sender);
    }

    //withdraw bid tokens if there is a top bidder that bidder more than msg.sender
    function withdrawFee() external onlyOwner {
        require(feeAmount > 0, "No Fee Amounts");
        coinracer.transferFrom(address(this), msg.sender, feeAmount);
        feeAmount = 0;
    }
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}