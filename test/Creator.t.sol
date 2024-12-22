// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "@forge-std/Test.sol";
import {Creator} from "@repo/Creator.sol";
import {CreatorFactory} from "@repo/CreatorFactory.sol";
import {Pausable} from "@openzeppelin-contracts/utils/Pausable.sol";

contract CreatorTest is Test {
    Creator public creator;
    CreatorFactory public factory;
    address public factoryOwner;
    address public creatorOwner;
    address public donator1;
    address public donator2;
    uint96 public constant INITIAL_FEE = 0.01 ether;

    event DonationReceived(
        address indexed donator,
        uint96 amount,
        string message,
        uint32 timestamp
    );
    event DonationAccepted(uint256 indexed donationId);
    event DonationBurned(uint256 indexed donationId);
    event ExcessWithdrawn(uint96 amount);

    function setUp() public {
        factoryOwner = makeAddr("factoryOwner");
        creatorOwner = makeAddr("creatorOwner");
        donator1 = makeAddr("donator1");
        donator2 = makeAddr("donator2");

        vm.prank(factoryOwner);
        factory = new CreatorFactory(INITIAL_FEE);

        vm.prank(creatorOwner);
        creator = new Creator(
            creatorOwner,
            "TestCreator",
            INITIAL_FEE,
            address(factory)
        );
    }

    function test_Constructor() public {
        assertEq(creator.owner(), creatorOwner);
        assertEq(creator.name(), "TestCreator");
        assertEq(creator.feePerDonation(), INITIAL_FEE);
        assertEq(creator.factory(), address(factory));
    }

    function test_Donate() public {
        uint96 donationAmount = 1 ether;
        string memory message = "Test donation";

        vm.deal(donator1, donationAmount);
        vm.prank(donator1);
        vm.expectEmit(true, true, true, true);
        emit DonationReceived(
            donator1,
            donationAmount,
            message,
            uint32(block.timestamp)
        );
        creator.donate{value: donationAmount}(message);

        assertEq(address(creator).balance, donationAmount);

        (
            address donator,
            uint96 amount,
            string memory storedMessage,
            ,
            bool isAccepted,
            bool isBurned
        ) = creator.getDonation(0);
        assertEq(donator, donator1);
        assertEq(amount, donationAmount);
        assertEq(storedMessage, message);
        assertFalse(isAccepted);
        assertFalse(isBurned);
    }

    function test_Donate_RevertIfInsufficientAmount() public {
        vm.deal(donator1, INITIAL_FEE);
        vm.prank(donator1);
        vm.expectRevert("Insufficient donation");
        creator.donate{value: INITIAL_FEE}("Test donation");
    }

    function test_AcceptDonation() public {
        // Setup donation
        uint96 donationAmount = 1 ether;
        vm.deal(donator1, donationAmount);
        vm.prank(donator1);
        creator.donate{value: donationAmount}("Test donation");

        uint256 initialCreatorBalance = creatorOwner.balance;
        uint256 initialFactoryBalance = address(factory).balance;

        // Accept donation
        vm.prank(creatorOwner);
        vm.expectEmit(true, true, true, true);
        emit DonationAccepted(0);
        creator.acceptDonation(0);

        // Verify balances
        assertEq(address(creator).balance, 0);
        assertEq(address(factory).balance, initialFactoryBalance + INITIAL_FEE);
        assertEq(
            creatorOwner.balance,
            initialCreatorBalance + donationAmount - INITIAL_FEE
        );

        // Verify donation state
        (, , , , bool isAccepted, bool isBurned) = creator.getDonation(0);
        assertTrue(isAccepted);
        assertFalse(isBurned);
    }

    function test_BurnDonation() public {
        // Setup donation
        uint96 donationAmount = 1 ether;
        vm.deal(donator1, donationAmount);
        vm.prank(donator1);
        creator.donate{value: donationAmount}("Test donation");

        uint256 initialDonatorBalance = donator1.balance;
        uint256 initialFactoryBalance = address(factory).balance;

        // Burn donation
        vm.prank(creatorOwner);
        vm.expectEmit(true, true, true, true);
        emit DonationBurned(0);
        creator.burnDonation(0);

        // Verify balances
        assertEq(address(creator).balance, 0);
        assertEq(address(factory).balance, initialFactoryBalance + INITIAL_FEE);
        assertEq(
            donator1.balance,
            initialDonatorBalance + donationAmount - INITIAL_FEE
        );

        // Verify donation state
        (, , , , bool isAccepted, bool isBurned) = creator.getDonation(0);
        assertFalse(isAccepted);
        assertTrue(isBurned);
    }

    function test_UpdateFeePerDonation() public {
        uint96 newFee = 0.02 ether;

        vm.prank(address(factory));
        creator.updateFeePerDonation(newFee);

        assertEq(creator.feePerDonation(), newFee);
    }

    function test_UpdateFeePerDonation_RevertIfNotFactory() public {
        vm.prank(creatorOwner);
        vm.expectRevert("Only factory");
        creator.updateFeePerDonation(0.02 ether);
    }

    function test_PauseUnpause() public {
        vm.startPrank(address(factory));
        creator.pause();
        vm.stopPrank();

        vm.deal(donator1, 1 ether);
        vm.prank(donator1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        creator.donate{value: 1 ether}("Test donation");

        vm.startPrank(address(factory));
        creator.unpause();
        vm.stopPrank();

        vm.deal(donator1, 1 ether);
        vm.prank(donator1);
        creator.donate{value: 1 ether}("Test donation"); // Should work now
    }

    receive() external payable {}
}
