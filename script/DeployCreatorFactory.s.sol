// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "@forge-std/Script.sol";
import {CreatorFactory} from "@repo/CreatorFactory.sol";

contract DeployCreatorFactory is Script {
    function run() public returns (CreatorFactory) {
        string memory rpc = vm.envString("RPC_URL");
        string memory pk = vm.envString("PRIVATE_KEY");

        vm.createFork(rpc);
        vm.startBroadcast(vm.parseAddress(pk));

        CreatorFactory factory = new CreatorFactory(0.01 ether);

        vm.stopBroadcast();
        return factory;
    }
}
