// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/ENSCAT.sol";
import "src/Resolver.sol";
import "src/Interface.sol";
// import "src/XCCIP.sol";
import "test/GenAddr.sol";

contract ENSCATScript is Script {
    using GenAddr for address;
    using Util for uint256;
    using Util for bytes;

    function run() external {
        vm.startBroadcast();

        /// @dev : Generate contract address before deployment
        address deployer = address(msg.sender);
        address enscatAddr = deployer.genAddr(vm.getNonce(deployer) + 1);
        Resolver resolver = new Resolver(enscatAddr);
        ENS100kCAT _enscat = new ENS100kCAT(address(resolver), 100_000);

        /// @dev : Check if generated address matches deployed address
        require(address(_enscat) == enscatAddr, "CRITICAL: ADDRESSES NOT MATCHING");

        /// @dev : Set Resolver, Controller
        iENS _ens = iENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
        //bytes32 _domainHash = _enscat.DomainHash();
        //_ens.setResolver(_domainHash, address(_enscat));
        _ens.setApprovalForAll(address(_enscat), true);

        /// @dev : CCIP Call
        // XCCIP xccip = new XCCIP(address(_enscat));

        vm.stopBroadcast();
        // xccip; //silence warning
    }
}
