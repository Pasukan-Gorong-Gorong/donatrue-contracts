// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "@forge-std/Script.sol";
import {Creator} from "@repo/Creator.sol";

contract DeployCreator is Script {
    function run(
        string memory name,
        uint96 feePerDonation,
        address factory,
        string memory bio,
        string memory avatar,
        string[] memory linkUrls,
        string[] memory linkLabels
    ) public returns (Creator) {
        string memory rpc = vm.envString("RPC_URL");
        string memory pk = vm.envString("PRIVATE_KEY");

        vm.createFork(rpc);
        vm.startBroadcast(vm.parseAddress(pk));

        Creator creator = new Creator(msg.sender, name, feePerDonation, factory);

        // Set additional information
        if (bytes(bio).length > 0) {
            creator.updateBio(bio);
        }
        if (bytes(avatar).length > 0) {
            creator.updateAvatar(avatar);
        }

        // Add links if provided
        require(linkUrls.length == linkLabels.length, "URLs and labels length mismatch");
        for (uint256 i = 0; i < linkUrls.length; i++) {
            creator.addLink(linkUrls[i], linkLabels[i]);
        }

        vm.stopBroadcast();
        return creator;
    }
}
