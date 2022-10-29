//SPDX-License-Identifier: WTFPL v6.9
pragma solidity >0.8.0 <0.9.0;

import "src/Interface.sol";

/**
 * @title Definitions
 */

abstract contract ENSCAT {
    /// @dev : ENS Contract Interface
    iENS public ENS;

    /// @dev Pause/Resume contract
    bool public active = true; // TESTNET

    /// @dev : Controller/Dev address
    address public Dev;

    /// @dev : Modifier to allow only dev
    modifier onlyDev() {
        if (msg.sender != Dev) {
            revert OnlyDev(Dev, msg.sender);
        }
        _;
    }

    // ERC721 details
    string public name = "100kCat.eth";
    string public symbol = "ENSCAT";

    /// @dev : Default resolver used by this contract
    address public DefaultResolver;

    /// @dev : Current/Live supply of subdomains
    uint256 public totalSupply;

    /// @dev : $ETH per subdomain mint
    uint256 public mintPrice = 0.001 ether; // TESTNET

    /// @dev : Opensea Contract URI
    string public contractURI = "ipfs://Qmblablabla";

    /// @dev : ERC2981 Royalty info; 1 = 1%
    uint8 public royalty = 10; // TESTNET

    /// @dev : IPFS hash of metadata directory
    string public metaIPFS = "Qmblablabla";

    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) internal _ownerOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    mapping(bytes4 => bool) public supportsInterface;
    mapping(uint256 => bytes32) public ID2Labelhash;
    mapping(bytes32 => uint256) public Namehash2ID;

    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event Approval(address indexed _owner, address indexed approved, uint256 indexed id);
    event ApprovalForAll(address indexed _owner, address indexed operator, bool approved);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error Unauthorized(address operator, address owner, uint256 id);
    error NotSubdomainOwner(address owner, address from, uint256 id);
    error InsufficientEtherSent(uint256 size, uint256 yourSize);
    error ERC721IncompatibleReceiver(address addr);
    error OnlyDev(address _dev, address _you);
    error InvalidTokenID(uint256 id);
    error MintingPaused();
    error MintEnded();
    error ZeroAddress();
    error IllegalBatch(string[3] list);
    error TooSoonToMint();
    error IllegalENS(string digits);
    error NotOwnerOrController(string digits);

    modifier isValidToken(uint256 id) {
        if (id >= totalSupply) {
            revert InvalidTokenID(id);
        }
        _;
    }

    /**
     * @dev : setInterface
     * @param sig : signature
     * @param value : boolean
     */
    function setInterface(bytes4 sig, bool value) external payable onlyDev {
        require(sig != 0xffffffff, "INVALID_INTERFACE_SELECTOR");
        supportsInterface[sig] = value;
    }

    /**
     * @dev : withdraw ether to multisig, anyone can trigger
     */
    function withdrawEther() external payable {
        (bool ok,) = Dev.call{value: address(this).balance}("");
        require(ok, "ETH_TRANSFER_FAILED");
    }

    /**
     * @dev : to be used in case some tokens get locked in the contract
     * @param token : token to release
     */
    function withdrawToken(address token) external payable {
        iERC20(token).transferFrom(address(this), Dev, iERC20(token).balanceOf(address(this)));
    }

    /// @dev : revert on fallback
    fallback() external payable {
        revert();
    }

    /// @dev : revert on receive
    receive() external payable {
        revert();
    }
}
