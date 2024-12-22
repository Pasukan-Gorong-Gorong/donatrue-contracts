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

    error CreatorExists();
    error CreatorNotFound();
    error NoFeesToWithdraw();
    error TransferFailed();

    constructor(uint96 _feePerDonation) Ownable(msg.sender) {
        feePerDonation = _feePerDonation;
    }

    function registerCreator(string calldata name) external whenNotPaused {
        if (creatorContracts[msg.sender] != address(0)) revert CreatorExists();

        Creator newCreator = new Creator(
            msg.sender,
            name,
            feePerDonation,
            address(this)
        );

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
        for (uint256 i = 0; i < length; ) {
            Creator(creators[i]).updateFeePerDonation(_feePerDonation);
            unchecked {
                ++i;
            }
        }
    }

    function withdrawCreatorExcess(address creatorAddress) external onlyOwner {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();

        Creator(creatorContract).withdrawExcessFunds();
    }

    function withdrawAllCreatorsExcess() external onlyOwner {
        uint256 length = creators.length;
        for (uint256 i = 0; i < length; ) {
            Creator(creators[i]).withdrawExcessFunds();
            unchecked {
                ++i;
            }
        }
    }

    function getCreatorContract(
        address creatorAddress
    ) external view returns (address) {
        return creatorContracts[creatorAddress];
    }

    function getAllCreators() external view returns (address[] memory) {
        return creators;
    }

    function getCreatorBalance(
        address creatorAddress
    ) external view returns (uint96 balance, uint96 pendingAmount) {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();
        return Creator(creatorContract).getContractBalance();
    }

    function pauseCreator(address creatorAddress) external onlyOwner {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();
        Creator(creatorContract).pause();
    }

    function unpauseCreator(address creatorAddress) external onlyOwner {
        address creatorContract = creatorContracts[creatorAddress];
        if (creatorContract == address(0)) revert CreatorNotFound();
        Creator(creatorContract).unpause();
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

        (bool success, ) = owner().call{value: balance}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(balance);
    }

    receive() external payable {}
}
