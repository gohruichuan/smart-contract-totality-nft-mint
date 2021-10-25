pragma solidity >=0.6.0 <=0.8.0;
//SPDX-License-Identifier: MIT

//import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//learn more: https://docs.openzeppelin.com/contracts/3.x/erc721

// GET LISTED ON OPENSEA: https://testnets.opensea.io/get-listed/step-two

contract Totality is ERC721, Ownable {
    address payable private constant TREASURY_WALLET = 0x836D5a18960f7Ab7dCF3261248B85838475f060C;
    address private _signerAddress = 0x7e3999B106E4Ef472E569b772bF7F7647D8F26Ba;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string private _tokenBaseURI =
        "https://api-nft-placeholder.herokuapp.com/api/metadata/";

    constructor() public ERC721("Totality", "Solar") {
        _setBaseURI(_tokenBaseURI);
    }

    uint256 public constant GIFT = 88;
    uint256 public constant PRIVATE = 800;
    uint256 public constant PUBLIC = 8000;
    uint256 public constant MAX_SUPPLY_LIMIT = GIFT + PRIVATE + PUBLIC;
    uint256 public constant PRICE = 0.08 ether;
    uint256 public constant LIMIT_PER_MINT = 5;

    mapping(address => bool) public presalerList; // stores presale wallet addresses
    mapping(address => uint256) public presalerListPurchases; // stores presale number of purchases

    uint256 public requested;
    uint256 public giftedAmountMinted;
    uint256 public publicAmountMinted;
    uint256 public privateAmountMinted;
    uint256 public presalePurchaseLimit = 2;
    bool public presaleLive;
    bool public saleLive;
    bool public locked;

    modifier notLocked() {
        require(!locked, "Contract metadata methods are locked");
        _;
    }

    function removeFromPresaleList(address[] calldata entries)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "NULL_ADDRESS");
            require(presalerList[entry], "PRESALER_DOESNT_EXIST");

            presalerList[entry] = false;
        }
    }

    function presaleBuy(bytes32 hash, bytes memory signature, string memory nonce, uint256 tokenQuantity) external payable {
        require(!saleLive && presaleLive, "PRESALE_CLOSED");
        require(totalSupply() < MAX_SUPPLY_LIMIT, "OUT_OF_STOCK");
        require(
            privateAmountMinted + tokenQuantity <= PRIVATE,
            "EXCEED_PRIVATE"
        );

        if(!presalerList[msg.sender]){
            require(matchAddresSigner(hash,signature), "DIRECT_MINT_DISALLOWED");
            presalerList[msg.sender] = true;
        }

        require( presalerListPurchases[msg.sender] + tokenQuantity <= presalePurchaseLimit, "EXCEED_ALLOC" );
        require(PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");

        privateAmountMinted += tokenQuantity;
        presalerListPurchases[msg.sender] += tokenQuantity;

        for (uint256 i = 0; i < tokenQuantity; i++) {
            _safeMint(msg.sender, totalSupply() + 1);
        }
        (bool success,) = TREASURY_WALLET.call{value:msg.value}("");
        require( success, "could not send");
    }

    function hashTransaction( address sender, uint256 qty, string memory nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(sender, qty, nonce))
            )
        );

        return hash;
    }

    function matchAddresSigner(bytes32 hash, bytes memory signature) private view returns (bool)
    {
        return _signerAddress == hash.recover(signature);
    }

    // ANTI-BOT launch Mint =========
    // function buy( bytes32 hash, bytes memory signature, string memory nonce, uint256 tokenQuantity) external payable {
    //     require(saleLive, "SALE_CLOSED");
    //     require(!presaleLive, "ONLY_PRESALE");
    //     require(matchAddresSigner(hashTransaction(msg.sender, tokens, nonce),signature), "DIRECT_MINT_DISALLOWED");
    //     require(!_usedNonces[nonce], "HASH_USED");
    //     require(totalSupply() < MAX_SUPPLY_LIMIT, "OUT_OF_STOCK");
    //     require(publicAmountMinted + tokenQuantity <= PUBLIC, "EXCEED_PUBLIC");
    //     require(tokenQuantity <= LIMIT_PER_MINT, "EXCEED_LIMIT_PER_MINT");
    //     require(PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");

    //     _usedNonces[nonce] = true;

    //     for (uint256 i = 0; i < tokenQuantity; i++) {
    //         publicAmountMinted++;
    //         _safeMint(msg.sender, totalSupply() + 1);
    //     }
    // }

    // BASIC launch Mint ==========
    function buy(uint256 tokenQuantity) external payable {
      require(saleLive, "SALE_CLOSED");
      require(!presaleLive, "ONLY_PRESALE");
      require(totalSupply() < MAX_SUPPLY_LIMIT, "OUT_OF_STOCK");
      require(publicAmountMinted + tokenQuantity <= PUBLIC, "EXCEED_PUBLIC");
      require(tokenQuantity <= LIMIT_PER_MINT, "EXCEED_LIMIT_PER_MINT");
      require(PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");

      for (uint256 i = 0; i < tokenQuantity; i++) {
        publicAmountMinted++;
        _safeMint(msg.sender, totalSupply() + 1);
      }
        (bool success,) = TREASURY_WALLET.call{value:msg.value}("");
        require( success, "could not send");
    }

    function gift(address[] calldata receivers) external onlyOwner {
        require(
            totalSupply() + receivers.length <= MAX_SUPPLY_LIMIT,
            "OUT_OF_STOCK"
        );
        require(giftedAmountMinted + receivers.length <= GIFT, "GIFTS_EMPTY");

        for (uint256 i = 0; i < receivers.length; i++) {
            giftedAmountMinted++;
            _safeMint(receivers[i], totalSupply() + 1);
        }
    }

    function isPresaler(address addr) external view returns (bool) {
        return presalerList[addr];
    }

    function presalePurchasedCount(address addr)
        external
        view
        returns (uint256)
    {
        return presalerListPurchases[addr];
    }

    // Owner functions for enabling presale, sale, revealing and setting the provenance hash
    function lockMetadata() external onlyOwner {
        locked = true;
    }

    function togglePresaleStatus() external onlyOwner {
        presaleLive = !presaleLive;
    }

    function toggleSaleStatus() external onlyOwner {
        saleLive = !saleLive;
    }

    function setBaseURI(string calldata URI) external onlyOwner notLocked {
        _tokenBaseURI = URI;
        _setBaseURI(URI);
    }

    //   function mintItem(address to, string memory tokenURI)
    //       external
    //       onlyOwner
    //       returns (uint256)
    //   {
    //       require( _tokenIds.current() < MAX_SUPPLY_LIMIT , "OUT_OF_STOCK");
    //       _tokenIds.increment();

    //       uint256 id = _tokenIds.current();
    //       publicAmountMinted++;
    //       _mint(to, id);
    //       _setTokenURI(id, tokenURI);

    //       return id;
    //   }

    //   event Request(address to, uint256 value);

    //   function requestMint()
    //       external
    //       payable
    //   {
    //     require( requested++ < MAX_SUPPLY_LIMIT , "DONE MINTING");
    //     require( msg.value >= PRICE, "NOT ENOUGH");
    //     (bool success,) = TREASURY_WALLET.call{value:msg.value}("");
    //     require( success, "could not send");
    //     emit Request(msg.sender, msg.value);
    //   }
    // }
}
