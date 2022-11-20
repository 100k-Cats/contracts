//SPDX-License-Identifier: WTFPL v6.9
pragma solidity >0.8.0 <0.9.0;

import "src/Interface.sol";
import "src/Util.sol";
import "src/Base.sol";
import "forge-std/console2.sol"; // TESTNET

/**
 * @author sshmatrix, on behalf of BENSYC
 * @title 100kCat Core
 */

contract ENS100kCAT is ENSCAT {
    using Util for uint256;
    using Util for bytes;
    using Util for bytes32;
    using Util for string;

    /// @dev : maximum supply of subdomains
    uint256 public immutable maxSupply;

    /// @dev : namehash of '100kcat.eth'
    bytes32 public immutable DomainHash;

    /**
     * @dev Constructor
     * @param _resolver : default Resolver
     * @param _maxSupply : maximum supply of subdomains
     */
    constructor(address _resolver, uint256 _maxSupply) {
        contractURI = "ipfs://QmZT2ZxQC27tkvLZCrVbC3EfPm1fpjixDMC77fuFAuNjGh"; // TESTNET
        Dev = msg.sender;
        ENS = iENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
        DefaultResolver = _resolver;
        DomainHash = keccak256(
            abi.encodePacked(keccak256(abi.encodePacked(bytes32(0), keccak256("eth"))), keccak256("100kcat0"))
        );
        maxSupply = _maxSupply;
        // Interface
        supportsInterface[type(iERC165).interfaceId] = true;
        supportsInterface[type(iERC173).interfaceId] = true;
        supportsInterface[type(iERC721Metadata).interfaceId] = true;
        supportsInterface[type(iERC721).interfaceId] = true;
        supportsInterface[type(iERC2981).interfaceId] = true;
    }

    /**
     * @dev EIP721: returns owner of token ID
     * @param id : token ID
     * @return : address of owner
     */
    function ownerOf(uint256 id) public view isValidToken(id) returns (address) {
        return _ownerOf[id];
    }

    /**
     * @dev mint() function for single sudomain
     * @param digits : subdomain to mint
     */
    function mint(string memory digits) external payable {
        // check if active
        if (!active) {
            revert MintingPaused();
        }
        // check supply
        if (totalSupply >= maxSupply) {
            revert MintEnded();
        }
        // check payment
        if (msg.value < mintPrice) {
            revert InsufficientEtherSent(mintPrice, msg.value);
        }
        // check if ENS belongs to 100k Club
        if (digits.strlen() != 5 || !digits.isNumeric()) {
            revert IllegalENS(digits);
        }
        // check permissions depending on phase of mint
        if (phase == 0) {
            revert TooSoonToMint();
        } else if (phase == 1) {
            // get ENS ownership
            address digitOwner = ENS.owner(keccak256(
                abi.encodePacked(keccak256(abi.encodePacked(bytes32(0), keccak256("eth"))), keccak256(abi.encodePacked(digits)))
            ));
            if (msg.sender != digitOwner) {
                revert NotOwnerOfENS(digits);
            }
        } else if (phase == 2) {
            // check whitelist
            require(whitelist[msg.sender], "NOT_IN_WHITELIST");
        }

        uint256 _id = totalSupply;
        bytes32 _labelhash = keccak256(abi.encodePacked(digits));
        address subOwner = ENS.owner(keccak256(abi.encodePacked(DomainHash, _labelhash)));
        // check if subdomain is available to mint
        if (subOwner != address(0)) {
            revert DigitNotAvailable(digits);
        }
        ENS.setSubnodeRecord(DomainHash, _labelhash, msg.sender, DefaultResolver, 0);
        ID2Label[_id] = digits;
        Namehash2ID[keccak256(abi.encodePacked(DomainHash, _labelhash))] = _id;
        unchecked {
            ++totalSupply;
            ++balanceOf[msg.sender];
        }
        _ownerOf[_id] = msg.sender;
        emit Transfer(address(0), msg.sender, _id);
    }

    /**
     * @dev : batchMint() function for sudomains
     * @param _list : list of subdomains
     */
    function batchMint(string[] calldata _list) external payable {
        // check if active
        if (!active) {
            revert MintingPaused();
        }
        // check batch size and supply
        uint256 batchSize = _list.length;
        if (batchSize > bigBatch[phase - 1] || totalSupply + batchSize > maxSupply) {
            revert IllegalBatch(_list);
        }
        // check payment
        if (msg.value < mintPrice * batchSize) {
            revert InsufficientEtherSent(mintPrice * batchSize, msg.value);
        }
        // check if ENSes belong to 100k Club
        for (uint8 i = 0; i < batchSize;) {
            string memory digits = _list[i];
            if (digits.strlen() != 5 || !digits.isNumeric()) {
                revert IllegalENS(digits);
            }
            unchecked{ i++; }
        }
        // check permissions depending on phase of mint
        if (phase == 0) {
            revert TooSoonToMint();
        } else if (phase == 1) {
            for (uint8 i = 0; i < batchSize;) {
                string memory digits = _list[i];
                // get ENS ownership
                address digitOwner = ENS.owner(keccak256(
                    abi.encodePacked(keccak256(abi.encodePacked(bytes32(0), keccak256("eth"))), keccak256(abi.encodePacked(digits)))
                ));
                if (msg.sender != digitOwner) {
                    revert NotOwnerOfENS(digits);
                }
                unchecked{ i++; }
            }
        } else if (phase == 2) {
            // check whitelist
            require(whitelist[msg.sender], "NOT_IN_WHITELIST");
        }

        uint256 _id = totalSupply;
        bytes32 _labelhash;
        for (uint8 i = 0; i < batchSize;) {
            _labelhash = keccak256(abi.encodePacked(_list[i]));
            // check if subdomain is available to mint
            address subOwner = ENS.owner(keccak256(abi.encodePacked(DomainHash, _labelhash)));
            if (subOwner != address(0)) {
                revert DigitNotAvailable(_list[i]);
            }
            ENS.setSubnodeRecord(DomainHash, _labelhash, msg.sender, DefaultResolver, 0);
            ID2Label[_id] = _list[i];
            Namehash2ID[keccak256(abi.encodePacked(DomainHash, _labelhash))] = _id;
            _ownerOf[_id] = msg.sender;
            emit Transfer(address(0), msg.sender, _id);
            unchecked {
                ++_id;
                i++;
            }
        }
        unchecked {
            totalSupply = _id;
            balanceOf[msg.sender] += batchSize;
        }
    }

    /**
     * @dev : generic _transfer function
     * @param from : address of sender
     * @param to : address of receiver
     * @param id : subdomain token ID
     */
    function _transfer(address from, address to, uint256 id, bytes memory data) internal {
        if (to == address(0)) {
            revert ZeroAddress();
        }

        if (_ownerOf[id] != from) {
            revert NotSubdomainOwner(_ownerOf[id], from, id);
        }

        if (msg.sender != _ownerOf[id] && !isApprovedForAll[from][msg.sender] && msg.sender != getApproved[id]) {
            revert Unauthorized(msg.sender, from, id);
        }

        ENS.setSubnodeOwner(DomainHash, keccak256(abi.encodePacked(ID2Label[id])), to);
        unchecked {
            --balanceOf[from]; // subtract from owner
            ++(balanceOf[to]); // add to receiver
        }
        _ownerOf[id] = to; // change ownership
        delete getApproved[id]; // reset approved
        emit Transfer(from, to, id);
        if (to.code.length > 0) {
            try iERC721Receiver(to).onERC721Received(msg.sender, from, id, data) returns (bytes4 retval) {
                if (retval != iERC721Receiver.onERC721Received.selector) {
                    revert ERC721IncompatibleReceiver(to);
                }
            } catch {
                revert ERC721IncompatibleReceiver(to);
            }
        }
    }

    /**
     * @dev : transfer function
     * @param from : from address
     * @param to : to address
     * @param id : token ID
     */
    function transferFrom(address from, address to, uint256 id) external payable {
        _transfer(from, to, id, "");
    }

    /**
     * @dev : safeTransferFrom function with extra data
     * @param from : from address
     * @param to : to address
     * @param id : token ID
     * @param data : extra data
     */
    function safeTransferFrom(address from, address to, uint256 id, bytes memory data) external payable {
        _transfer(from, to, id, data);
    }

    /**
     * @dev : safeTransferFrom function
     * @param from : from address
     * @param to : to address
     * @param id : token ID
     */
    function safeTransferFrom(address from, address to, uint256 id) external payable {
        _transfer(from, to, id, "");
    }

    /**
     * @dev : grants approval for a token ID
     * @param approved : operator address to be approved
     * @param id : token ID
     */
    function approve(address approved, uint256 id) external payable {
        if (msg.sender != _ownerOf[id]) {
            revert Unauthorized(msg.sender, _ownerOf[id], id);
        }
        getApproved[id] = approved;
        emit Approval(msg.sender, approved, id);
    }

    /**
     * @dev : sets Controller (for all tokens)
     * @param operator : operator address to be set as Controller
     * @param approved : bool to set
     */
    function setApprovalForAll(address operator, bool approved) external payable {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev : generate metadata path corresponding to token ID
     * @param id : token ID
     * @return : IPFS path to metadata directory
     */
    function tokenURI(uint256 id) external view isValidToken(id) returns (string memory) {
        return string.concat("ipfs://", metaIPFS, "/", ID2Label[id], ".json");
    }

    /**
     * @dev : royalty payment to Dev (or multi-sig)
     * @param id : token ID
     * @param _salePrice : sale price
     * @return : ether amount to be paid as royalty to Dev (or multi-sig)
     */
    function royaltyInfo(uint256 id, uint256 _salePrice) external view returns (address, uint256) {
        id; //silence warning
        return (Dev, _salePrice / 10_000 * royalty);
    }

    // Contract Management

    /**
     * @dev : transfer contract ownership to new Dev
     * @param newDev : new Dev
     */
    function transferOwnership(address newDev) external onlyDev {
        emit OwnershipTransferred(Dev, newDev);
        Dev = newDev;
    }

    /**
     * @dev : get owner of contract
     * @return : address of controlling dev or multi-sig wallet
     */
    function owner() external view returns (address) {
        return Dev;
    }

    /**
     * @dev : Toggle if contract is active or paused, only Dev can toggle
     */
    function toggleActive() external onlyDev {
        active = !active;
    }

    /**
     * @dev : sets Default Resolver
     * @param _resolver : resolver address
     */
    function setDefaultResolver(address _resolver) external onlyDev {
        DefaultResolver = _resolver;
    }

    /**
     * @dev : sets OpenSea contractURI
     * @param _contractURI : URI value
     */
    function setContractURI(string calldata _contractURI) external onlyDev {
        contractURI = _contractURI;
    }

    /**
     * @dev EIP2981 royalty standard
     * @param _royalty : royalty (100 = 1 %)
     */
    function setRoyalty(uint16 _royalty) external onlyDev {
        royalty = _royalty;
    }

    /**
     * @dev : sets Phase
     * @param value : phase
     */
    function setPhase(uint8 value) external onlyDev {
        require(value >= 1 && value <= 3, "BAD_VALUE");
        phase = value;
    }
}
