// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "@forge-std/Test.sol";
import {CreatorFactory} from "@repo/CreatorFactory.sol";
import {Creator} from "@repo/Creator.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin-contracts/utils/Pausable.sol";

contract CreatorFactoryTest is Test {
    CreatorFactory public factory;
    address public owner;
    address public creator1;
    address public creator2;
    uint96 public constant INITIAL_FEE = 0.01 ether;

    event CreatorRegistered(
        address indexed creatorAddress,
        address contractAddress,
        string name
    );
    event FeeUpdated(uint96 newFee);
    event FeesWithdrawn(uint96 amount);
    event CreatorExcessWithdrawn(
        address indexed creatorContract,
        uint96 amount
    );

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
        factory.registerCreator(creatorName);

        address creatorContract = factory.creatorContracts(creator1);
        assertEq(factory.creatorCount(), 1);
        assertTrue(creatorContract != address(0));

        address[] memory allCreators = factory.getAllCreators();
        assertEq(allCreators.length, 1);
        assertEq(allCreators[0], creatorContract);
    }

    function test_RegisterCreator_RevertIfAlreadyRegistered() public {
        vm.startPrank(creator1);
        factory.registerCreator("Creator1");

        vm.expectRevert(CreatorFactory.CreatorExists.selector);
        factory.registerCreator("Creator1Again");
        vm.stopPrank();
    }

    function test_UpdateFeePerDonation() public {
        uint96 newFee = 0.02 ether;

        // Register a creator first
        vm.prank(creator1);
        factory.registerCreator("Creator1");

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit FeeUpdated(newFee);
        factory.updateFeePerDonation(newFee);

        assertEq(factory.feePerDonation(), newFee);

        // Check if creator contract fee was updated
        address creatorContract = factory.creatorContracts(creator1);
        assertEq(Creator(creatorContract).feePerDonation(), newFee);
    }

    function test_UpdateFeePerDonation_RevertIfNotOwner() public {
        vm.prank(creator1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                creator1
            )
        );
        factory.updateFeePerDonation(0.02 ether);
    }

    function test_PauseUnpause() public {
        vm.startPrank(owner);
        factory.pause();
        vm.stopPrank();

        vm.prank(creator1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        factory.registerCreator("Creator1");

        vm.startPrank(owner);
        factory.unpause();
        vm.stopPrank();

        vm.prank(creator1);
        factory.registerCreator("Creator1"); // Should work now
    }

    function test_WithdrawFees() public {
        // Setup: register creator and make donation
        vm.prank(creator1);
        factory.registerCreator("Creator1");
        address creatorContract = factory.creatorContracts(creator1);

        // Make donation that will generate fees
        vm.deal(address(this), 1 ether);
        Creator(creatorContract).donate{value: 1 ether}("Test donation");

        // Accept donation to transfer fee to factory
        vm.prank(creator1);
        Creator(creatorContract).acceptDonation(0);

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

    receive() external payable {}
}
