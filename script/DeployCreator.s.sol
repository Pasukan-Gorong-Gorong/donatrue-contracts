// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "@forge-std/Script.sol";
import {Creator} from "@repo/Creator.sol";

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

        Creator creator = new Creator(
            msg.sender,
            name,
            feePerDonation,
            factory
        );

        // Set additional information
        if (bytes(bio).length > 0) {
            creator.updateBio(bio);
        }
        if (bytes(avatar).length > 0) {
            creator.updateAvatar(avatar);
        }

        // Add links if provided
        if (bytes(linkUrls).length > 0 && bytes(linkLabels).length > 0) {
            string[] memory urls = _split(linkUrls, ",");
            string[] memory labels = _split(linkLabels, ",");
            require(
                urls.length == labels.length,
                "URLs and labels length mismatch"
            );
            for (uint256 i = 0; i < urls.length; i++) {
                creator.addLink(urls[i], labels[i]);
            }
        }

        vm.stopBroadcast();
        return creator;
    }

    function _split(
        string memory str,
        string memory delimiter
    ) internal pure returns (string[] memory) {
        uint count = 1;
        for (uint i = 0; i < bytes(str).length; i++) {
            if (bytes(str)[i] == bytes(delimiter)[0]) count++;
        }

        string[] memory parts = new string[](count);
        uint start = 0;
        uint partIndex = 0;

        for (uint i = 0; i <= bytes(str).length; i++) {
            if (
                i == bytes(str).length || bytes(str)[i] == bytes(delimiter)[0]
            ) {
                uint length = i - start;
                bytes memory part = new bytes(length);
                for (uint j = 0; j < length; j++) {
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
