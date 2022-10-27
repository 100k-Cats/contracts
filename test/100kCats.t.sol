// SPDX-License-Identifier: WTFPL v6.9
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "src/BENSYC.sol";
import "src/Resolver.sol";
import "src/XCCIP.sol";
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
contract BENSYCTest is Test {
    using stdStorage for StdStorage;
    using GenAddr for address;

    /// @dev : set contract as controller for boredensyachtclub.eth
    function setUp() public {
        address _addr = ENS.owner(bensyc.DomainHash());
        require(_addr != address(0), "Revert: 0 address detected");
        vm.prank(_addr);
        ENS.setApprovalForAll(address(bensyc), true);
    }

    BoredENSYachtClub public bensyc;

    //XCCIP public _xccip;
    Resolver public resolver;
    uint256 public mintPrice;
    iENS public ENS = iENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    CannotReceive721 public _notReceiver;
    CanReceive721 public _isReceiver;

    constructor() {
        address deployer = address(this);
        address bensycAddr = deployer.genAddr(vm.getNonce(deployer) + 1);
        resolver = new Resolver(bensycAddr);
        uint256 startTime = block.timestamp;
        bensyc = new BoredENSYachtClub(address(resolver), 100, startTime);
        require(address(bensyc) == bensycAddr, "CRITICAL: ADDRESSES NOT MATCHING");
        _notReceiver = new CannotReceive721();
        _isReceiver = new CanReceive721();
        mintPrice = bensyc.mintPrice();
    }

    /// @dev : verify name & symbol
    function testCheckNameSymbol() public {
        assertEq(bensyc.name(), "BoredENSYachtClub.eth");
        assertEq(bensyc.symbol(), "BENSYC");
    }

    /// @dev : verify zero supply at start
    function testCheckZeroSupply() public {
        assertEq(bensyc.totalSupply(), 0);
    }

    /// @dev : check if contract is authorised by boredensyachtclub.eth
    function testCheckContractIsController() public {
        address _addr = ENS.owner(bensyc.DomainHash());
        assertTrue(ENS.isApprovedForAll(_addr, address(bensyc)));
    }

    /// @dev : test minting one subdomain, verify ownership & resolver
    function testSubdomainMint() public {
        bensyc.mint{value: mintPrice}();
        assertEq(bensyc.ownerOf(0), address(this));
        assertEq(bensyc.balanceOf(address(this)), 1);
        assertEq(ENS.owner(bensyc.ID2Namehash(0)), address(this));
        assertEq(ENS.resolver(bensyc.ID2Namehash(0)), address(bensyc.DefaultResolver()));
    }

    /// @dev : test minting out the entire supply one by one
    function testMintTokensIndividually() public {
        uint256 maxSupply = 100;
        for (uint256 i = 0; i < maxSupply; i++) {
            bensyc.mint{value: mintPrice}();
            assertEq(bensyc.ownerOf(i), address(this));
            assertEq(ENS.owner(bensyc.ID2Namehash(i)), address(this));
            assertEq(ENS.resolver(bensyc.ID2Namehash(i)), address(bensyc.DefaultResolver()));
        }
        assertEq(bensyc.totalSupply(), 100);
        vm.expectRevert(abi.encodeWithSelector(BENSYC.InvalidTokenID.selector, uint256(100)));
        bensyc.ownerOf(100);
        assertEq(bensyc.ownerOf(99), address(this));
    }

    /// @dev : test minting a batch with size < 13
    function testBatchMint() public {
        uint256 batchSize = 10;
        bensyc.batchMint{value: batchSize * mintPrice}(batchSize);
        for (uint256 i = 0; i < batchSize; i++) {
            assertEq(bensyc.ownerOf(i), address(this));
            assertEq(ENS.owner(bensyc.ID2Namehash(i)), address(this));
            assertEq(ENS.resolver(bensyc.ID2Namehash(i)), address(bensyc.DefaultResolver()));
        }
    }

    /// @dev : verify that batchMint() fails when batchSize > 12
    function testCannotMintOversizedBatch() public {
        uint256 batchSize = 13;
        vm.expectRevert(abi.encodeWithSelector(BENSYC.OversizedBatch.selector));
        bensyc.batchMint{value: batchSize * mintPrice}(batchSize);
    }

    /// @dev : verify that owner can transfer subdomain
    function testSubdomainTransfer() public {
        bensyc.mint{value: mintPrice}();
        address _addr = bensyc.ownerOf(0);
        bensyc.transferFrom(_addr, address(0xc0de4c0cac01a), 0);
        _addr = bensyc.ownerOf(0);
        assertEq(_addr, address(0xc0de4c0cac01a));
    }

    /// @dev : verify that contract (= parent controller) cannot transfer a subdomain
    function testControllerContractCannotTransfer() public {
        bensyc.mint{value: mintPrice}();
        vm.expectRevert(
            abi.encodeWithSelector(BENSYC.NotSubdomainOwner.selector, address(this), address(0xc0de4c0cac01a), 0)
        );
        bensyc.transferFrom(address(0xc0de4c0cac01a), address(0xc0de4c0cac01a), 0);
    }

    /// @dev : verify that valid contract can receive a subdomain
    function testExternalContractCanReceive() public {
        bensyc.mint{value: mintPrice}();
        bensyc.transferFrom(address(this), address(_isReceiver), 0);
    }

    /// @dev : verify that contract (= parent controller) cannot receive a subdomain
    function testControllerContractCannotReceive() public {
        bensyc.mint{value: mintPrice}();
        vm.expectRevert(abi.encodeWithSelector(BENSYC.ERC721IncompatibleReceiver.selector, address(_notReceiver)));
        bensyc.transferFrom(address(this), address(_notReceiver), 0);
    }
}
