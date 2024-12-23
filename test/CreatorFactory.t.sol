// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "@forge-std/Test.sol";
import {CreatorFactory} from "@repo/CreatorFactory.sol";
import {Creator, Link} from "@repo/Creator.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract CreatorFactoryTest is Test {
    CreatorFactory public factory;
    address public owner;
    address public creator1;
    address public creator2;
    uint96 public constant INITIAL_FEE = 0.01 ether;

    event CreatorRegistered(address indexed creatorAddress, address contractAddress, string name);
    event FeeUpdated(uint96 newFee);
    event FeesWithdrawn(uint96 amount);
    event CreatorExcessWithdrawn(address indexed creatorContract, uint96 amount);

    function setUp() public {
        owner = makeAddr("owner");
        creator1 = makeAddr("creator1");
        creator2 = makeAddr("creator2");

        vm.prank(owner);
        factory = new CreatorFactory(INITIAL_FEE);
    }

    function test_Constructor() public {
        assertEq(factory.owner(), owner);
        assertEq(factory.feePerDonation(), INITIAL_FEE);
        assertEq(factory.creatorCount(), 0);
    }

    function test_RegisterCreator() public {
        string memory creatorName = "Creator1";
        vm.prank(creator1);
        Link[] memory emptyLinks = new Link[](0);
        factory.registerCreator(creatorName, "", "", emptyLinks);

        address creatorContract = factory.creatorContracts(creator1);
        assertEq(factory.creatorCount(), 1);
        assertTrue(creatorContract != address(0));

        address[] memory allCreators = factory.getAllCreators();
        assertEq(allCreators.length, 1);
        assertEq(allCreators[0], creatorContract);
    }

    function test_RegisterCreator_RevertIfAlreadyRegistered() public {
        vm.startPrank(creator1);
        Link[] memory emptyLinks = new Link[](0);
        factory.registerCreator("Creator1", "", "", emptyLinks);

        vm.expectRevert(CreatorFactory.CreatorExists.selector);
        factory.registerCreator("Creator1Again", "", "", emptyLinks);
        vm.stopPrank();
    }

    function test_UpdateFeePerDonation() public {
        uint96 newFee = 0.02 ether;

        // Register a creator first
        vm.prank(creator1);
        Link[] memory emptyLinks = new Link[](0);
        factory.registerCreator("Creator1", "", "", emptyLinks);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit FeeUpdated(newFee);
        factory.updateFeePerDonation(newFee);

        assertEq(factory.feePerDonation(), newFee);

        // Check if creator contract fee was updated
        address creatorContract = factory.creatorContracts(creator1);
        assertEq(Creator(payable(creatorContract)).feePerDonation(), newFee);
    }

    function test_UpdateFeePerDonation_RevertIfNotOwner() public {
        vm.prank(creator1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, creator1));
        factory.updateFeePerDonation(0.02 ether);
    }

    function test_PauseUnpause() public {
        vm.startPrank(owner);
        factory.pause();
        vm.stopPrank();

        vm.prank(creator1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        Link[] memory emptyLinks = new Link[](0);
        factory.registerCreator("Creator1", "", "", emptyLinks);

        vm.startPrank(owner);
        factory.unpause();
        vm.stopPrank();

        vm.prank(creator1);
        factory.registerCreator("Creator1", "", "", emptyLinks); // Should work now
    }

    function test_WithdrawFees() public {
        // Setup: register creator and make donation
        vm.prank(creator1);
        Link[] memory emptyLinks = new Link[](0);
        factory.registerCreator("Creator1", "", "", emptyLinks);
        address creatorContract = factory.creatorContracts(creator1);

        // Make donation that will generate fees
        vm.deal(address(this), 1 ether);
        Creator(payable(creatorContract)).donate{value: 1 ether}("Test donation");

        // Accept donation to transfer fee to factory
        vm.prank(creator1);
        Creator(payable(creatorContract)).acceptDonation(0);

        uint256 initialBalance = owner.balance;

        // Withdraw fees
        vm.prank(owner);
        factory.withdrawFees();

        assertGt(owner.balance, initialBalance);
    }

    function test_WithdrawFees_RevertIfNoFees() public {
        vm.prank(owner);
        vm.expectRevert(CreatorFactory.NoFeesToWithdraw.selector);
        factory.withdrawFees();
    }

    function test_GetCreators() public {
        // Register multiple creators
        vm.startPrank(creator1);
        Link[] memory emptyLinks = new Link[](0);
        factory.registerCreator("Creator1", "", "", emptyLinks);
        vm.stopPrank();

        vm.startPrank(creator2);
        factory.registerCreator("Creator2", "", "", emptyLinks);
        vm.stopPrank();

        // Test pagination
        (address[] memory creators, uint256 total) = factory.getCreators(0, 1);
        assertEq(total, 2);
        assertEq(creators.length, 1);
        assertEq(creators[0], factory.creatorContracts(creator1));

        // Get next page
        (creators, total) = factory.getCreators(1, 1);
        assertEq(creators.length, 1);
        assertEq(creators[0], factory.creatorContracts(creator2));
    }

    function test_GetDonationsByDonator() public {
        // Setup creators and donations
        vm.startPrank(creator1);
        Link[] memory emptyLinks = new Link[](0);
        factory.registerCreator("Creator1", "", "", emptyLinks);
        address creator1Contract = factory.creatorContracts(creator1);
        vm.stopPrank();

        vm.startPrank(creator2);
        factory.registerCreator("Creator2", "", "", emptyLinks);
        address creator2Contract = factory.creatorContracts(creator2);
        vm.stopPrank();

        // Make donations to both creators
        address donator = address(0x123);
        vm.deal(donator, 5 ether);

        vm.startPrank(donator);
        Creator(payable(creator1Contract)).donate{value: 1 ether}("Donation to Creator1 - 1");
        Creator(payable(creator1Contract)).donate{value: 1 ether}("Donation to Creator1 - 2");
        Creator(payable(creator2Contract)).donate{value: 1 ether}("Donation to Creator2");
        vm.stopPrank();

        // Test pagination across all creators
        (CreatorFactory.DonationWithCreator[] memory donations, uint256 total) =
            factory.getDonationsByDonator(donator, 0, 2);

        assertEq(total, 3);
        assertEq(donations.length, 2);
        assertEq(donations[0].creator, creator1Contract);
        assertEq(donations[0].message, "Donation to Creator1 - 1");
        assertEq(donations[1].creator, creator1Contract);
        assertEq(donations[1].message, "Donation to Creator1 - 2");

        // Get next page
        (donations, total) = factory.getDonationsByDonator(donator, 2, 2);
        assertEq(donations.length, 1);
        assertEq(donations[0].creator, creator2Contract);
        assertEq(donations[0].message, "Donation to Creator2");
    }

    receive() external payable {}
}
