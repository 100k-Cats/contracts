// SPDX-License-Identifier: WTFPL v6.9
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "src/ENSCAT.sol";
import "src/Resolver.sol";
// import "src/XCCIP.sol";
import "test/GenAddr.sol";

// @dev : for testing
contract CannotReceive721 {
    address _a = address(0xc0de4c0cac01a);
}

contract CanReceive721 {
    // @dev : generic onERC721Received tester
    address notPure;

    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes memory _data)
        external
        returns (bytes4)
    {
        notPure = _operator;
        _from;
        _tokenId;
        _data;
        return CanReceive721.onERC721Received.selector;
    }
}

// @dev : Tester
contract ENSCATTest is Test {
    using stdStorage for StdStorage;
    using GenAddr for address;

    /// @dev : set contract as controller for 100kcat.eth
    function setUp() public {
        address _addr = ENS.owner(enscat.DomainHash());
        address digitOwner = ENS.owner(keccak256(
            abi.encodePacked(keccak256(abi.encodePacked(bytes32(0), keccak256("eth"))), keccak256(abi.encodePacked(digits)))
        ));
        require(_addr == digitOwner, "Ownership not set"); // Dev must own both
        require(_addr != address(0), "Revert: 0 address detected");
        vm.prank(_addr);
        ENS.setApprovalForAll(address(enscat), true);
    }

    string public digits = "07777"; 
    string public illegalENS = "0897";
    ENS100kCAT public enscat;
    //XCCIP public _xccip;
    Resolver public resolver;
    uint256 public mintPrice;
    iENS public ENS = iENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    CannotReceive721 public _notReceiver;
    CanReceive721 public _isReceiver;
    address public actor = ENS.owner(keccak256(
            abi.encodePacked(keccak256(abi.encodePacked(bytes32(0), keccak256("eth"))), keccak256(abi.encodePacked(digits)))
        ));

    constructor() {
        address deployer = address(this);
        address enscatAddr = deployer.genAddr(vm.getNonce(deployer) + 1);
        resolver = new Resolver(enscatAddr);
        uint256 startTime = block.timestamp;
        enscat = new ENS100kCAT(address(resolver), 100, startTime);
        require(address(enscat) == enscatAddr, "CRITICAL: ADDRESSES NOT MATCHING");
        _notReceiver = new CannotReceive721();
        _isReceiver = new CanReceive721();
        mintPrice = enscat.mintPrice();
    }

    /// @dev : verify name & symbol
    function testCheckNameSymbol() public {
        assertEq(enscat.name(), "100kCat.eth");
        assertEq(enscat.symbol(), "ENSCAT");
    }

    /// @dev : verify zero supply at start
    function testCheckZeroSupply() public {
        assertEq(enscat.totalSupply(), 0);
    }

    /// @dev : check if contract is authorised by 100kcat.eth
    function testCheckContractIsController() public {
        address _addr = ENS.owner(enscat.DomainHash());
        assertTrue(ENS.isApprovedForAll(_addr, address(enscat)));
    }

    /// @dev : test minting one subdomain, verify ownership & resolver
    function testSubdomainMint() public {
        vm.prank(actor);
        enscat.mint{value: mintPrice}(digits);
        assertEq(enscat.ownerOf(0), actor);
        assertEq(enscat.balanceOf(actor), 1);
        assertEq(ENS.owner(enscat.ID2Namehash(0)), actor);
        assertEq(ENS.resolver(enscat.ID2Namehash(0)), address(enscat.DefaultResolver()));
    }

    /// @dev : test minting out the entire supply one by one
    function testMintTokensIndividually() public {
        uint256 maxSupply = 100;
        for (uint256 i = 0; i < maxSupply; i++) {
            vm.prank(actor);
            enscat.mint{value: mintPrice}(digits);
            assertEq(enscat.ownerOf(i), actor);
            assertEq(ENS.owner(enscat.ID2Namehash(i)), actor);
            assertEq(ENS.resolver(enscat.ID2Namehash(i)), address(enscat.DefaultResolver()));
        }
        assertEq(enscat.totalSupply(), 100);
        vm.expectRevert(abi.encodeWithSelector(ENSCAT.InvalidTokenID.selector, uint256(100)));
        enscat.ownerOf(100);
        assertEq(enscat.ownerOf(99), actor);
    }

    /// @dev : test minting a batch with size = 3
    function testFullBatchMint() public {
        uint256 batchSize = 3;
        string[3] memory list = ["42059", "07777","00234"];
        vm.prank(actor);
        enscat.batchMint{value: batchSize * mintPrice}(batchSize, list);
        for (uint256 i = 0; i < batchSize; i++) {
            assertEq(enscat.ownerOf(i), actor);
            assertEq(ENS.owner(enscat.ID2Namehash(i)), actor);
            assertEq(ENS.resolver(enscat.ID2Namehash(i)), address(enscat.DefaultResolver()));
        }
    }
 
    /// @dev : verify that batchMint() succeeds when batchSize <= 3
    function testPartialBatchMint() public {
        uint256 batchSize = 2;
        string[3] memory list = ["42059", "16342", ""];
        vm.prank(actor);
        enscat.batchMint{value: batchSize * mintPrice}(batchSize, list);
    }

    /// @dev : verify that owner can transfer subdomain
    function testSubdomainTransfer() public {
        vm.prank(actor);
        enscat.mint{value: mintPrice}(digits);
        address _addr = enscat.ownerOf(0);
        vm.prank(actor);
        enscat.transferFrom(_addr, address(0xc0de4c0cac01a), 0);
        _addr = enscat.ownerOf(0);
        assertEq(_addr, address(0xc0de4c0cac01a));
    }

    /// @dev : verify that contract (= parent controller) cannot transfer a subdomain
    function testControllerContractCannotTransfer() public {
        vm.prank(actor);
        enscat.mint{value: mintPrice}(digits);
        vm.expectRevert(
            abi.encodeWithSelector(ENSCAT.NotSubdomainOwner.selector, actor, address(0xc0de4c0cac01a), 0)
        );
        enscat.transferFrom(address(0xc0de4c0cac01a), address(0xc0de4c0cac01a), 0);
    }

    /// @dev : verify that valid contract can receive a subdomain
    function testExternalContractCanReceive() public {
        vm.prank(actor);
        enscat.mint{value: mintPrice}(digits);
        vm.prank(actor);
        enscat.transferFrom(actor, address(_isReceiver), 0);
    }

    /// @dev : verify that contract (= parent controller) cannot receive a subdomain
    function testControllerContractCannotReceive() public {
        vm.prank(actor);
        enscat.mint{value: mintPrice}(digits);
        vm.expectRevert(abi.encodeWithSelector(ENSCAT.ERC721IncompatibleReceiver.selector, address(_notReceiver)));
        vm.prank(actor);
        enscat.transferFrom(actor, address(_notReceiver), 0);
    }
}
