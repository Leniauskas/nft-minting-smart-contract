
// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

// import relevant standard contracts
import "https://github.com/chiru-labs/ERC721A/blob/main/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";


contract NFT_with_burn_and_merkle is ERC721A, Ownable, AccessControlEnumerable {

    uint256 public maxTotalSupply = 999;            // maximum supply for NFT tokens
    uint256 public pricePerToken = 0.001 ether;     // price per token
    uint256 public tokensBurned = 0;                // amount of tokens burned counter
    uint256 private disableBurnTime = 518400;       // how long burning mechanism will last - in this case 6 days
    uint256 deployedTime;                           // time at which the contract was deployed

    bytes32 private merkleRoot;                     // storing merkle root

    uint8 private maxToken_WLsale = 1;              // amount of tokens allowed to mint in private sale per wallet
    uint8 private maxToken_Public = 5;              // amount of tokens allowed to mint in public sale per wallet
    
    enum SaleState{ CLOSED, PRIVATE, PUBLIC }       // variable for controlling mint state (closed, private and public)
    SaleState public saleState = SaleState.CLOSED;  // defaulf value = sale is closed
  
    mapping(address => uint256) presaleMinted;      // mapping for tracking wallets that already minted in private sale
    mapping(address => uint256) publicMinted;       // mapping for tracking wallets that already minted in public sale

    string _baseTokenURI;                           // base token unique identifier
    address _burnerAddress;                         // where to send burned NFT tokens
    

    constructor() ERC721A("NFT_name", "NFT") {      // constructor with NFT name and its abbreviation
      _setupRole(DEFAULT_ADMIN_ROLE, _msgSender()); // contract deployer is the admin
      deployedTime = block.timestamp;               // when contract was deployed
    }

    // change the price of NFT token
    function setPrice(uint256 newPrice) public {
      require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Cannot set price");
      pricePerToken = newPrice;
    }

    // withdraw funds from the contract
    function withdraw() public onlyOwner {
      require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Cannot withdraw");
        payable(owner()).transfer(address(this).balance);
    }

    // change the sale state (either private, public or closed
    function setSaleState(SaleState newState) public {
      require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Cannot alter sale state");
      saleState = newState;
    }

    // set new merkle root for verification of whitelisted addresses for private minting
    function setMerkleRoot(bytes32 newRoot) public {
      require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Cannot set merkle root");
      merkleRoot = newRoot;
    }

    // for minting in presale, in other words private sale
    function presale(uint256 amount, bytes32[] calldata proof) public payable {
      require (saleState == SaleState.PRIVATE, "Sale state should be private"); // has to be private sale state
      require(totalSupply() < maxTotalSupply, "Max supply reached"); // cannot suprass total supply
      bool isValid = MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(msg.sender))); // checks if your address belongs to private sale
      require(isValid, "You are not in the valid whitelist"); // your address has to be in private sale in order to mint

      // do not exceed allowe amount of tokens to mint
      require(amount + presaleMinted[msg.sender] <= maxToken_WLsale, "Your token amount reached out max");
      require(presaleMinted[msg.sender] < maxToken_WLsale, "You've already minted all");
      // paying contract required amount for each token
      uint256 amountToPay = amount * pricePerToken;
      require(amountToPay <= msg.value, "Provided not enough Ether for purchase");
      presaleMinted[msg.sender] += amount;
      // minting
      _safeMint(_msgSender(), amount);
    }

    // public mint 
    function publicsale(uint256 amount) public payable {
      require (saleState == SaleState.PUBLIC, "Sale state should be public"); // has to be public sale state
      require(totalSupply() < maxTotalSupply, "Max supply reached"); // cannot suprass total supply
      require(amount + publicMinted[msg.sender] <= maxToken_Public, "Your token amount reached out max"); // do not exceed allowe amount of tokens to mint
      // paying contract required amount for each token
      uint256 amountToPay = amount * pricePerToken;
      require(amountToPay <= msg.value, "Provided not enough Ether for purchase");
      publicMinted[msg.sender] += amount;
      // minting
      _safeMint(_msgSender(), amount);
    }


    // for token burning mechanism
    function burnMany(uint256[] calldata tokenIds) public {
      require(_msgSender() == _burnerAddress, "Only burner can burn tokens"); // callling this function from burning address only
      uint256 nowTime = block.timestamp; // what is the time now
      require(nowTime - deployedTime <= disableBurnTime, "Burn is available only for 6 days"); // make sure burn is still active
      // burned desired token ids
      for (uint256 i; i < tokenIds.length; i++) {
        _burn(tokenIds[i]);
      }
      maxTotalSupply -= tokenIds.length; // decrease total supply upon burning
      tokensBurned += tokenIds.length; // increase number of burned tokens
    }

    // set new burner address
    function setBurnerAddress(address burnerAddress) public {
      require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller cannot set burn address");
      _burnerAddress = burnerAddress;
    }

    // view token base URI
    function _baseURI() internal view virtual override returns (string memory) {
      return _baseTokenURI;
    }

    // set new token base URI
    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    // overriding supportsInterface to avoid two or more base classes definining function with same name and parameter type
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, AccessControlEnumerable) returns (bool) {
      return super.supportsInterface(interfaceId);
    }
}