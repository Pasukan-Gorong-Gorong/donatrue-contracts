// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-contracts/access/Ownable.sol";
import "@openzeppelin-contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin-contracts/utils/Pausable.sol";

contract Creator is Ownable, ReentrancyGuard, Pausable {
    struct Donation {
        address donator;
        uint96 amount;
        string message;
        uint32 timestamp;
        bool isAccepted;
        bool isBurned;
    }

    string public name;
    uint96 public feePerDonation;
    address public immutable factory;
    Donation[] private donations;
    uint96 private totalPendingAmount;

    event DonationReceived(
        address indexed donator,
        uint96 amount,
        string message,
        uint32 timestamp
    );
    event DonationAccepted(uint256 indexed donationId);
    event DonationBurned(uint256 indexed donationId);
    event ExcessWithdrawn(uint96 amount);

    error OnlyFactoryOwner();

    modifier onlyFactory() {
        if (msg.sender != factory) revert("Only factory");
        _;
    }

    modifier onlyFactoryOwner() {
        if (msg.sender != Ownable(factory).owner()) revert OnlyFactoryOwner();
        _;
    }

    constructor(
        address initialOwner,
        string memory _name,
        uint96 _feePerDonation,
        address _factory
    ) Ownable(initialOwner) {
        name = _name;
        feePerDonation = _feePerDonation;
        factory = _factory;
    }

    function donate(
        string calldata message
    ) external payable nonReentrant whenNotPaused {
        if (msg.value <= feePerDonation) revert("Insufficient donation");
        if (msg.value > type(uint96).max) revert("Donation too large");

        uint96 amount = uint96(msg.value);
        unchecked {
            totalPendingAmount += amount;
            donations.push(
                Donation({
                    donator: msg.sender,
                    amount: amount,
                    message: message,
                    timestamp: uint32(block.timestamp),
                    isAccepted: false,
                    isBurned: false
                })
            );
        }

        emit DonationReceived(
            msg.sender,
            amount,
            message,
            uint32(block.timestamp)
        );
    }

    function acceptDonation(
        uint256 donationId
    ) external onlyOwner nonReentrant whenNotPaused {
        if (donationId >= donations.length) revert("Invalid donation ID");

        Donation storage donation = donations[donationId];
        if (donation.isAccepted || donation.isBurned)
            revert("Already processed");

        donation.isAccepted = true;

        // Calculate fee and transfer amounts
        uint96 fee = feePerDonation;
        uint96 donationAmount = donation.amount;
        uint96 creatorAmount;
        unchecked {
            creatorAmount = donationAmount - fee;
            totalPendingAmount -= donationAmount;
        }

        // Transfer fee to factory
        (bool feeSuccess, ) = factory.call{value: fee}("");
        if (!feeSuccess) revert("Fee transfer failed");

        // Transfer remaining amount to creator
        (bool success, ) = owner().call{value: creatorAmount}("");
        if (!success) revert("Transfer failed");

        emit DonationAccepted(donationId);
    }

    function burnDonation(
        uint256 donationId
    ) external onlyOwner nonReentrant whenNotPaused {
        if (donationId >= donations.length) revert("Invalid donation ID");

        Donation storage donation = donations[donationId];
        if (donation.isAccepted || donation.isBurned)
            revert("Already processed");

        donation.isBurned = true;

        // Return donation to donator minus fee
        uint96 fee = feePerDonation;
        uint96 donationAmount = donation.amount;
        uint96 returnAmount;
        unchecked {
            returnAmount = donationAmount - fee;
            totalPendingAmount -= donationAmount;
        }

        // Transfer fee to factory
        (bool feeSuccess, ) = factory.call{value: fee}("");
        if (!feeSuccess) revert("Fee transfer failed");

        // Return remaining amount to donator
        (bool success, ) = donation.donator.call{value: returnAmount}("");
        if (!success) revert("Return failed");

        emit DonationBurned(donationId);
    }

    function withdrawExcessFunds() external nonReentrant onlyFactoryOwner {
        uint96 contractBalance = uint96(address(this).balance);
        uint96 excessAmount = contractBalance - totalPendingAmount;
        if (excessAmount > 0) {
            (bool success, ) = msg.sender.call{value: excessAmount}("");
            if (!success) revert("Transfer failed");
            emit ExcessWithdrawn(excessAmount);
        }
    }

    function getDonationsCount() external view returns (uint256) {
        return donations.length;
    }

    function getDonation(
        uint256 donationId
    )
        external
        view
        returns (
            address donator,
            uint96 amount,
            string memory message,
            uint32 timestamp,
            bool isAccepted,
            bool isBurned
        )
    {
        if (donationId >= donations.length) revert("Invalid donation ID");
        Donation storage donation = donations[donationId];
        return (
            donation.donator,
            donation.amount,
            donation.message,
            donation.timestamp,
            donation.isAccepted,
            donation.isBurned
        );
    }

    function getContractBalance()
        external
        view
        returns (uint96 balance, uint96 pendingAmount)
    {
        return (uint96(address(this).balance), totalPendingAmount);
    }

    function updateFeePerDonation(uint96 _feePerDonation) external onlyFactory {
        feePerDonation = _feePerDonation;
    }

    function pause() external onlyFactory {
        _pause();
    }

    function unpause() external onlyFactory {
        _unpause();
    }
}
