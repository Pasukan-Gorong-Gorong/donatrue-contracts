// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "@forge-std/Script.sol";
import {CreatorFactory} from "@repo/CreatorFactory.sol";
import {Creator, Link} from "@repo/Creator.sol";
import {console} from "@forge-std/console.sol";

contract DeployCreatorFactory is Script {
    function run() public returns (CreatorFactory) {
        string memory rpc = vm.envString("RPC_URL");
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.createFork(rpc);
        vm.startBroadcast(pk);

        // Deploy and verify Creator implementation first
        Link[] memory emptyLinks = new Link[](0);
        Creator creatorImpl = new Creator(address(1), 0, address(1), "", "", "", emptyLinks);

        console.log("Creator implementation deployed at:", address(creatorImpl));

        // Deploy factory with initial fee
        CreatorFactory factory = new CreatorFactory(0.01 ether);

        vm.stopBroadcast();
        return factory;
    }
}
