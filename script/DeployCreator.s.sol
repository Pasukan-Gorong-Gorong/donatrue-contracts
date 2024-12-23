// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "@forge-std/Script.sol";
import {Creator, Link} from "@repo/Creator.sol";

contract DeployCreator is Script {
    function run() public returns (Creator) {
        string memory rpc = vm.envString("RPC_URL");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        string memory name = vm.envString("CREATOR_NAME");
        address factory = vm.envAddress("FACTORY_ADDRESS");
        uint96 feePerDonation = uint96(vm.envUint("FEE_PER_DONATION"));

        // Optional parameters
        string memory bio = vm.envOr("BIO", string(""));
        string memory avatar = vm.envOr("AVATAR", string(""));
        string memory linkUrls = vm.envOr("LINK_URLS", string(""));
        string memory linkLabels = vm.envOr("LINK_LABELS", string(""));

        vm.createFork(rpc);
        vm.startBroadcast(pk);

        // Create links array
        Link[] memory links;
        if (bytes(linkUrls).length > 0 && bytes(linkLabels).length > 0) {
            string[] memory urls = _split(linkUrls, ",");
            string[] memory labels = _split(linkLabels, ",");
            require(urls.length == labels.length, "URLs and labels length mismatch");
            links = new Link[](urls.length);
            for (uint256 i = 0; i < urls.length; i++) {
                links[i] = Link({url: urls[i], label: labels[i]});
            }
        } else {
            links = new Link[](0);
        }

        Creator creator = new Creator(msg.sender, feePerDonation, factory, name, bio, avatar, links);

        vm.stopBroadcast();
        return creator;
    }

    function _split(string memory str, string memory delimiter) internal pure returns (string[] memory) {
        uint256 count = 1;
        for (uint256 i = 0; i < bytes(str).length; i++) {
            if (bytes(str)[i] == bytes(delimiter)[0]) count++;
        }

        string[] memory parts = new string[](count);
        uint256 start = 0;
        uint256 partIndex = 0;

        for (uint256 i = 0; i <= bytes(str).length; i++) {
            if (i == bytes(str).length || bytes(str)[i] == bytes(delimiter)[0]) {
                uint256 length = i - start;
                bytes memory part = new bytes(length);
                for (uint256 j = 0; j < length; j++) {
                    part[j] = bytes(str)[start + j];
                }
                parts[partIndex] = string(part);
                partIndex++;
                start = i + 1;
            }
        }

        return parts;
    }
}
