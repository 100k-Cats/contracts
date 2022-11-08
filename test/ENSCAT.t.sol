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

    string public digits = "00075"; 
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
        enscat = new ENS100kCAT(address(resolver), 10);
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

    /// @dev : test minting one subdomain, verify ownership & resolver in Phase 1
    function testPhase1Mint() public {
        vm.prank(actor);
        enscat.mint{value: mintPrice}(digits);
        assertEq(enscat.ownerOf(0), actor);
        assertEq(enscat.balanceOf(actor), 1);
        assertEq(ENS.owner(enscat.ID2Namehash(0)), actor);
        assertEq(ENS.resolver(enscat.ID2Namehash(0)), address(enscat.DefaultResolver()));
    }

    /// @dev : test minting a batch with size <= bigBatch in Phase 1
    function testPhase1BatchMint() public {
        // "42059", "07777", "00234", "00081", "00033"
        string[] memory _list = new string[](4);
        _list[0] = "42059";
        _list[1] = "07777";
        _list[2] = "00234";
        _list[3] = "00081";
        vm.prank(actor);
        enscat.batchMint{value: _list.length * mintPrice}(_list);
        for (uint256 i = 0; i < _list.length; i++) {
            assertEq(enscat.ownerOf(i), actor);
            assertEq(ENS.owner(enscat.ID2Namehash(i)), actor);
            assertEq(ENS.resolver(enscat.ID2Namehash(i)), address(enscat.DefaultResolver()));
        }
    }

    /// @dev : test minting one subdomain, verify ownership & resolver in Phase 2
    function testPhase2Mint() public {
        // start phase 2
        enscat.setEpochs([block.timestamp - 200, block.timestamp, block.timestamp + 200]);
        address[] memory _addrAllow = new address[](1);
        _addrAllow[0] = actor;
        // add minter to whitelist
        enscat.addToWhitelist(_addrAllow);
        string memory notOwned = "02345";
        vm.prank(actor);
        enscat.mint{value: mintPrice}(notOwned);
        assertEq(enscat.ownerOf(0), actor);
        assertEq(enscat.balanceOf(actor), 1);
        assertEq(ENS.owner(enscat.ID2Namehash(0)), actor);
        assertEq(ENS.resolver(enscat.ID2Namehash(0)), address(enscat.DefaultResolver()));
        // remove minter from whitelist
        enscat.removeFromWhitelist(_addrAllow);
        vm.prank(actor);
        vm.expectRevert("NOT_IN_WHITELIST");
        enscat.mint{value: mintPrice}(notOwned);
    }

    /// @dev : test minting a batch with size <= bigBatch in Phase 2
    function testPhase2BatchMint() public {
        // start phase 2
        enscat.setEpochs([block.timestamp - 200, block.timestamp, block.timestamp + 200]);
        address[] memory _addrAllow = new address[](1);
        _addrAllow[0] = actor;
        // add minter to whitelist
        enscat.addToWhitelist(_addrAllow);
        // "42059", "07777", "00234", "00081", "00033"
        string[] memory _list = new string[](4);
        _list[0] = "12361";
        _list[1] = "07347";
        _list[2] = "09464";
        _list[3] = "00681";
        vm.prank(actor);
        enscat.batchMint{value: _list.length * mintPrice}(_list);
        for (uint256 i = 0; i < _list.length; i++) {
            assertEq(enscat.ownerOf(i), actor);
            assertEq(ENS.owner(enscat.ID2Namehash(i)), actor);
            assertEq(ENS.resolver(enscat.ID2Namehash(i)), address(enscat.DefaultResolver()));
        }
        // remove minter from whitelist
        enscat.removeFromWhitelist(_addrAllow);
        vm.prank(actor);
        vm.expectRevert("NOT_IN_WHITELIST");
        enscat.batchMint{value: _list.length * mintPrice}(_list);
    }

    /// @dev : test minting one subdomain, verify ownership & resolver in Phase 3
    function testPhase3Mint() public {
        // start phase 3
        enscat.setEpochs([block.timestamp - 400, block.timestamp - 200, block.timestamp]);
        string memory notOwned = "08462";
        vm.prank(actor);
        enscat.mint{value: mintPrice}(notOwned);
        assertEq(enscat.ownerOf(0), actor);
        assertEq(enscat.balanceOf(actor), 1);
        assertEq(ENS.owner(enscat.ID2Namehash(0)), actor);
        assertEq(ENS.resolver(enscat.ID2Namehash(0)), address(enscat.DefaultResolver()));
    }

    /// @dev : test minting a batch with size <= bigBatch in Phase 3
    function testPhase3BatchMint() public {
        // start phase 3
        enscat.setEpochs([block.timestamp - 400, block.timestamp - 200, block.timestamp]);
        // "42059", "07777", "00234", "00081", "00033"
        string[] memory _list = new string[](4);
        _list[0] = "12361";
        _list[1] = "07347";
        _list[2] = "09464";
        _list[3] = "00681";
        vm.prank(actor);
        enscat.batchMint{value: _list.length * mintPrice}(_list);
        for (uint256 i = 0; i < _list.length; i++) {
            assertEq(enscat.ownerOf(i), actor);
            assertEq(ENS.owner(enscat.ID2Namehash(i)), actor);
            assertEq(ENS.resolver(enscat.ID2Namehash(i)), address(enscat.DefaultResolver()));
        }
    }

    /// @dev : verify that same digit cannot be minted twice
    function testCannotMintDigitTwice() public {
        /// first: expect success
        vm.prank(actor);
        enscat.mint{value: mintPrice}(digits);
        assertEq(enscat.ownerOf(0), actor);
        /// second: expect revert
        vm.prank(actor);
        vm.expectRevert(abi.encodeWithSelector(ENSCAT.DigitNotAvailable.selector, string(digits)));
        enscat.mint{value: mintPrice}(digits);
    }

    /// @dev : verify that same digit cannot be minted twice in a batch
    function testCannotMintDigitTwiceInBatch() public {
        string[] memory _list = new string[](3);
        _list[0] = "42059";
        _list[1] = "07777";
        _list[2] = "42059";
        vm.prank(actor);
        vm.expectRevert(abi.encodeWithSelector(ENSCAT.DigitNotAvailable.selector, string(_list[2])));
        enscat.batchMint{value: _list.length * mintPrice}(_list);
    }
 
    /// @dev : verify that batchMint() fails when batchSize > bigbatch
    function testCannotMintOversizedBatch() public {
        string[] memory _list = new string[](6);
        _list[0] = "42059";
        _list[1] = "07777";
        _list[2] = "00234";
        _list[3] = "00033";
        _list[4] = "00075";
        _list[5] = "00081";
        vm.prank(actor);
        vm.expectRevert(abi.encodeWithSelector(ENSCAT.IllegalBatch.selector, _list));
        enscat.batchMint{value: _list.length * mintPrice}(_list);
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
