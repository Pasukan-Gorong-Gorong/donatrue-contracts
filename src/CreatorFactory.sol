// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-contracts/access/Ownable.sol";
import "@openzeppelin-contracts/utils/Pausable.sol";
import "@repo/Creator.sol";

contract CreatorFactory is Ownable, Pausable {
    uint96 public feePerDonation;
    uint32 public creatorCount;
    mapping(address => address) public creatorContracts;
    address[] private creators;

    event CreatorRegistered(address indexed creatorAddress, address contractAddress, string name);
    event FeeUpdated(uint96 newFee);
    event FeesWithdrawn(uint96 amount);
    event CreatorExcessWithdrawn(address indexed creatorContract, uint96 amount);

    error CreatorExists();
    error CreatorNotFound();
    error NoFeesToWithdraw();
    error TransferFailed();

    constructor(uint96 _feePerDonation) Ownable(msg.sender) {
        feePerDonation = _feePerDonation;
    }

    function registerCreator(string calldata name, string calldata bio, string calldata avatar, Link[] calldata links)
        external
        whenNotPaused
    {
        if (creatorContracts[msg.sender] != address(0)) revert CreatorExists();

        Link[] memory linksArray = new Link[](links.length);
        for (uint256 i = 0; i < links.length; i++) {
            linksArray[i] = links[i];
        }

        Creator newCreator = new Creator(msg.sender, feePerDonation, address(this), name, bio, avatar, linksArray);

        creatorContracts[msg.sender] = address(newCreator);
        creators.push(address(newCreator));
        unchecked {
            ++creatorCount;
        }

        emit CreatorRegistered(msg.sender, address(newCreator), name);
    }

    function updateFeePerDonation(uint96 _feePerDonation) external onlyOwner {
        feePerDonation = _feePerDonation;
        emit FeeUpdated(_feePerDonation);

        uint256 length = creators.length;
        for (uint256 i = 0; i < length;) {
            Creator(payable(creators[i])).updateFeePerDonation(_feePerDonation);
            unchecked {
                ++i;
            }
        }
    }

    function withdrawCreatorExcess(address creatorAddress) external onlyOwner {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();

        Creator(payable(creatorContract)).withdrawExcessFunds();
    }

    function withdrawAllCreatorsExcess() external onlyOwner {
        uint256 length = creators.length;
        for (uint256 i = 0; i < length;) {
            Creator(payable(creators[i])).withdrawExcessFunds();
            unchecked {
                ++i;
            }
        }
    }

    function getCreatorContract(address creatorAddress) external view returns (address) {
        return creatorContracts[creatorAddress];
    }

    function getAllCreators() external view returns (address[] memory) {
        return creators;
    }

    function getCreatorBalance(address creatorAddress) external view returns (uint96 balance, uint96 pendingAmount) {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();
        return Creator(payable(creatorContract)).getContractBalance();
    }

    function pauseCreator(address creatorAddress) external onlyOwner {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();
        Creator(payable(creatorContract)).pause();
    }

    function unpauseCreator(address creatorAddress) external onlyOwner {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();
        Creator(payable(creatorContract)).unpause();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawFees() external onlyOwner {
        uint96 balance = uint96(address(this).balance);
        if (balance == 0) revert NoFeesToWithdraw();

        (bool success,) = owner().call{value: balance}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(balance);
    }

    function getCreators(uint256 offset, uint256 limit) external view returns (address[] memory, uint256) {
        uint256 total = creators.length;
        if (offset >= total) {
            return (new address[](0), total);
        }

        uint256 size = total - offset;
        if (size > limit) {
            size = limit;
        }

        address[] memory result = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            result[i] = creators[offset + i];
        }

        return (result, total);
    }

    struct DonationWithCreator {
        address creator;
        address donator;
        uint96 amount;
        string message;
        uint32 timestamp;
        bool isAccepted;
        bool isBurned;
    }

    function getDonationsByDonator(address donator, uint256 offset, uint256 limit)
        external
        view
        returns (DonationWithCreator[] memory result, uint256 total)
    {
        // First count total donations
        total = 0;
        for (uint256 i = 0; i < creators.length; i++) {
            (, uint256 creatorTotal) = Creator(payable(creators[i])).getDonationsByDonator(donator, 0, 0);
            total += creatorTotal;
        }

        if (total == 0 || offset >= total) {
            return (new DonationWithCreator[](0), total);
        }

        // Calculate size of return array
        uint256 size = total - offset;
        if (size > limit) {
            size = limit;
        }

        result = new DonationWithCreator[](size);
        uint256 resultIndex = 0;
        uint256 skipped = 0;

        // Fill result array
        for (uint256 i = 0; i < creators.length && resultIndex < size; i++) {
            Creator creator = Creator(payable(creators[i]));
            (Creator.Donation[] memory donations,) = creator.getDonationsByDonator(donator, 0, type(uint256).max);

            for (uint256 j = 0; j < donations.length && resultIndex < size; j++) {
                if (skipped < offset) {
                    skipped++;
                    continue;
                }
                result[resultIndex] = DonationWithCreator({
                    creator: creators[i],
                    donator: donations[j].donator,
                    amount: donations[j].amount,
                    message: donations[j].message,
                    timestamp: donations[j].timestamp,
                    isAccepted: donations[j].isAccepted,
                    isBurned: donations[j].isBurned
                });
                resultIndex++;
            }
        }

        return (result, total);
    }

    receive() external payable {}
}
