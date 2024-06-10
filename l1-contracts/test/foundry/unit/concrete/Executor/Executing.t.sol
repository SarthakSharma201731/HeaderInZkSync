// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// solhint-disable max-line-length

import {Vm} from "forge-std/Test.sol";
import {ExecutorTest} from "./_Executor_Shared.t.sol";
import {Utils, L2_SYSTEM_CONTEXT_ADDRESS} from "../Utils/Utils.sol";
import {L2_BOOTLOADER_ADDRESS} from "../../../../../cache/solpp-generated-contracts/common/L2ContractAddresses.sol";
import {COMMIT_TIMESTAMP_NOT_OLDER, REQUIRED_L2_GAS_PRICE_PER_PUBDATA} from "../../../../../cache/solpp-generated-contracts/zksync/Config.sol";
import {IExecutor, SystemLogKey} from "../../../../../cache/solpp-generated-contracts/zksync/interfaces/IExecutor.sol";

// solhint-enable max-line-length

contract ExecutingTest is ExecutorTest {
    function setUp() public {
        vm.warp(COMMIT_TIMESTAMP_NOT_OLDER + 1);
        currentTimestamp = block.timestamp;

        bytes[] memory correctL2Logs = Utils.createSystemLogs();
        correctL2Logs[uint256(uint256(SystemLogKey.PACKED_BATCH_AND_L2_BLOCK_TIMESTAMP_KEY))] = Utils.constructL2Log(
            true,
            L2_SYSTEM_CONTEXT_ADDRESS,
            uint256(SystemLogKey.PACKED_BATCH_AND_L2_BLOCK_TIMESTAMP_KEY),
            Utils.packBatchTimestampAndBlockTimestamp(currentTimestamp, currentTimestamp)
        );

        bytes memory l2Logs = Utils.encodePacked(correctL2Logs);

        newCommitBatchInfo.systemLogs = l2Logs;
        newCommitBatchInfo.timestamp = uint64(currentTimestamp);

        IExecutor.CommitBatchInfo[] memory commitBatchInfoArray = new IExecutor.CommitBatchInfo[](1);
        commitBatchInfoArray[0] = newCommitBatchInfo;

        IExecutor.HeaderUpdate[] memory headerArray = new IExecutor.HeaderUpdate[](1);
        headerArray[0] = Header;

        vm.prank(validator);
        vm.recordLogs();
        executor.commitBatches(genesisStoredBatchInfo, commitBatchInfoArray, headerArray);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32[] memory emptyArray;
        Header = IExecutor.HeaderUpdate({
            attestedHeader: IExecutor.BeaconBlockHeader({
                slot: 0,
                proposerIndex: 0,
                parentRoot: bytes32(0),
                stateRoot: bytes32(0),
                bodyRoot: bytes32(0)
            }),
            finalizedHeader: IExecutor.BeaconBlockHeader({
                slot: 0,
                proposerIndex: 0,
                parentRoot: bytes32(0),
                stateRoot: bytes32(0),
                bodyRoot: bytes32(0)
            }),
            finalityBranch: emptyArray ,
            nextSyncCommitteeRoot: bytes32(0),
            nextSyncCommitteeBranch: emptyArray ,
            executionStateRoot: bytes32(0),
            executionStateRootBranch: emptyArray ,
            blockNumber: 0,
            blockNumberBranch: emptyArray ,
            signature: IExecutor.BLSAggregatedSignature({
                participation: 0,
                proof: IExecutor.Groth16Proof({
                    a: [uint256(0), uint256(0)],
                    b: [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
                    c: [uint256(0), uint256(0)]
                })
            })
        });

        newStoredBatchInfo = IExecutor.StoredBatchInfo({
            batchNumber: 1,
            batchHash: entries[0].topics[2],
            indexRepeatedStorageChanges: 0,
            numberOfLayer1Txs: 0,
            priorityOperationsHash: keccak256(""),
            l2LogsTreeRoot: 0,
            timestamp: currentTimestamp,
            commitment: entries[0].topics[3],
            header: Header
        });

        IExecutor.StoredBatchInfo[] memory storedBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        storedBatchInfoArray[0] = newStoredBatchInfo;

        vm.prank(validator);
        executor.proveBatches(genesisStoredBatchInfo, storedBatchInfoArray, proofInput);
    }

    function test_RevertWhen_ExecutingBlockWithWrongBatchNumber() public {
        IExecutor.StoredBatchInfo memory wrongNewStoredBatchInfo = newStoredBatchInfo;
        wrongNewStoredBatchInfo.batchNumber = 10; // Correct is 1

        IExecutor.StoredBatchInfo[] memory storedBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        storedBatchInfoArray[0] = wrongNewStoredBatchInfo;

        vm.prank(validator);
        vm.expectRevert(bytes.concat("k"));
        executor.executeBatches(storedBatchInfoArray);
    }

    function test_RevertWhen_ExecutingBlockWithWrongData() public {
        IExecutor.StoredBatchInfo memory wrongNewStoredBatchInfo = newStoredBatchInfo;
        wrongNewStoredBatchInfo.timestamp = 0; // incorrect timestamp

        IExecutor.StoredBatchInfo[] memory storedBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        storedBatchInfoArray[0] = wrongNewStoredBatchInfo;

        vm.prank(validator);
        vm.expectRevert(bytes.concat("exe10"));
        executor.executeBatches(storedBatchInfoArray);
    }

    function test_RevertWhen_ExecutingRevertedBlockWithoutCommittingAndProvingAgain() public {
        vm.prank(validator);
        executor.revertBatches(0);

        IExecutor.StoredBatchInfo[] memory storedBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        storedBatchInfoArray[0] = newStoredBatchInfo;

        vm.prank(validator);
        vm.expectRevert(bytes.concat("n"));
        executor.executeBatches(storedBatchInfoArray);
    }

    function test_RevertWhen_ExecutingUnavailablePriorityOperationHash() public {
        vm.prank(validator);
        executor.revertBatches(0);

        bytes32 arbitraryCanonicalTxHash = Utils.randomBytes32("arbitraryCanonicalTxHash");
        bytes32 chainedPriorityTxHash = keccak256(bytes.concat(keccak256(""), arbitraryCanonicalTxHash));

        bytes[] memory correctL2Logs = Utils.createSystemLogs();
        correctL2Logs[uint256(SystemLogKey.PACKED_BATCH_AND_L2_BLOCK_TIMESTAMP_KEY)] = Utils.constructL2Log(
            true,
            L2_SYSTEM_CONTEXT_ADDRESS,
            uint256(SystemLogKey.PACKED_BATCH_AND_L2_BLOCK_TIMESTAMP_KEY),
            Utils.packBatchTimestampAndBlockTimestamp(currentTimestamp, currentTimestamp)
        );
        correctL2Logs[uint256(SystemLogKey.CHAINED_PRIORITY_TXN_HASH_KEY)] = Utils.constructL2Log(
            true,
            L2_BOOTLOADER_ADDRESS,
            uint256(SystemLogKey.CHAINED_PRIORITY_TXN_HASH_KEY),
            chainedPriorityTxHash
        );
        correctL2Logs[uint256(SystemLogKey.NUMBER_OF_LAYER_1_TXS_KEY)] = Utils.constructL2Log(
            true,
            L2_BOOTLOADER_ADDRESS,
            uint256(SystemLogKey.NUMBER_OF_LAYER_1_TXS_KEY),
            bytes32(uint256(1))
        );

        IExecutor.CommitBatchInfo memory correctNewCommitBatchInfo = newCommitBatchInfo;
        correctNewCommitBatchInfo.systemLogs = Utils.encodePacked(correctL2Logs);
        correctNewCommitBatchInfo.priorityOperationsHash = chainedPriorityTxHash;
        correctNewCommitBatchInfo.numberOfLayer1Txs = 1;

        IExecutor.CommitBatchInfo[] memory correctNewCommitBatchInfoArray = new IExecutor.CommitBatchInfo[](1);
        correctNewCommitBatchInfoArray[0] = correctNewCommitBatchInfo;

        IExecutor.HeaderUpdate memory headerUpdate = Header;

        IExecutor.HeaderUpdate[] memory headerArray = new IExecutor.HeaderUpdate[](1);
        headerArray[0] = headerUpdate;

        vm.prank(validator);
        vm.recordLogs();
        executor.commitBatches(genesisStoredBatchInfo, correctNewCommitBatchInfoArray, headerArray);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        IExecutor.StoredBatchInfo memory correctNewStoredBatchInfo = newStoredBatchInfo;
        correctNewStoredBatchInfo.batchHash = entries[0].topics[2];
        correctNewStoredBatchInfo.numberOfLayer1Txs = 1;
        correctNewStoredBatchInfo.priorityOperationsHash = chainedPriorityTxHash;
        correctNewStoredBatchInfo.commitment = entries[0].topics[3];

        IExecutor.StoredBatchInfo[] memory correctNewStoredBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        correctNewStoredBatchInfoArray[0] = correctNewStoredBatchInfo;

        vm.prank(validator);
        executor.proveBatches(genesisStoredBatchInfo, correctNewStoredBatchInfoArray, proofInput);

        vm.prank(validator);
        vm.expectRevert(bytes.concat("s"));
        executor.executeBatches(correctNewStoredBatchInfoArray);
    }

    function test_RevertWhen_ExecutingWithUnmatchedPriorityOperationHash() public {
        vm.prank(validator);
        executor.revertBatches(0);

        bytes32 arbitraryCanonicalTxHash = Utils.randomBytes32("arbitraryCanonicalTxHash");
        bytes32 chainedPriorityTxHash = keccak256(bytes.concat(keccak256(""), arbitraryCanonicalTxHash));

        bytes[] memory correctL2Logs = Utils.createSystemLogs();
        correctL2Logs[uint256(SystemLogKey.PACKED_BATCH_AND_L2_BLOCK_TIMESTAMP_KEY)] = Utils.constructL2Log(
            true,
            L2_SYSTEM_CONTEXT_ADDRESS,
            uint256(SystemLogKey.PACKED_BATCH_AND_L2_BLOCK_TIMESTAMP_KEY),
            Utils.packBatchTimestampAndBlockTimestamp(currentTimestamp, currentTimestamp)
        );
        correctL2Logs[uint256(SystemLogKey.CHAINED_PRIORITY_TXN_HASH_KEY)] = Utils.constructL2Log(
            true,
            L2_BOOTLOADER_ADDRESS,
            uint256(SystemLogKey.CHAINED_PRIORITY_TXN_HASH_KEY),
            chainedPriorityTxHash
        );
        correctL2Logs[uint256(SystemLogKey.NUMBER_OF_LAYER_1_TXS_KEY)] = Utils.constructL2Log(
            true,
            L2_BOOTLOADER_ADDRESS,
            uint256(SystemLogKey.NUMBER_OF_LAYER_1_TXS_KEY),
            bytes32(uint256(1))
        );
        IExecutor.CommitBatchInfo memory correctNewCommitBatchInfo = newCommitBatchInfo;
        correctNewCommitBatchInfo.systemLogs = Utils.encodePacked(correctL2Logs);
        correctNewCommitBatchInfo.priorityOperationsHash = chainedPriorityTxHash;
        correctNewCommitBatchInfo.numberOfLayer1Txs = 1;

        IExecutor.CommitBatchInfo[] memory correctNewCommitBatchInfoArray = new IExecutor.CommitBatchInfo[](1);
        correctNewCommitBatchInfoArray[0] = correctNewCommitBatchInfo;

        IExecutor.HeaderUpdate[] memory headerArray = new IExecutor.HeaderUpdate[](1);
        headerArray[0] = Header;

        vm.prank(validator);
        vm.recordLogs();
        executor.commitBatches(genesisStoredBatchInfo, correctNewCommitBatchInfoArray, headerArray);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        IExecutor.StoredBatchInfo memory correctNewStoredBatchInfo = newStoredBatchInfo;
        correctNewStoredBatchInfo.batchHash = entries[0].topics[2];
        correctNewStoredBatchInfo.numberOfLayer1Txs = 1;
        correctNewStoredBatchInfo.priorityOperationsHash = chainedPriorityTxHash;
        correctNewStoredBatchInfo.commitment = entries[0].topics[3];

        IExecutor.StoredBatchInfo[] memory correctNewStoredBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        correctNewStoredBatchInfoArray[0] = correctNewStoredBatchInfo;

        vm.prank(validator);
        executor.proveBatches(genesisStoredBatchInfo, correctNewStoredBatchInfoArray, proofInput);

        bytes32 randomFactoryDeps0 = Utils.randomBytes32("randomFactoryDeps0");

        bytes[] memory factoryDeps = new bytes[](1);
        factoryDeps[0] = bytes.concat(randomFactoryDeps0);

        uint256 gasPrice = 1000000000;
        uint256 l2GasLimit = 1000000;
        uint256 baseCost = mailbox.l2TransactionBaseCost(gasPrice, l2GasLimit, REQUIRED_L2_GAS_PRICE_PER_PUBDATA);
        uint256 l2Value = 10 ether;
        uint256 totalCost = baseCost + l2Value;

        mailbox.requestL2Transaction{value: totalCost}(
            address(0),
            l2Value,
            bytes(""),
            l2GasLimit,
            REQUIRED_L2_GAS_PRICE_PER_PUBDATA,
            factoryDeps,
            address(0)
        );

        vm.prank(validator);
        vm.expectRevert(bytes.concat("x"));
        executor.executeBatches(correctNewStoredBatchInfoArray);
    }

    function test_RevertWhen_CommittingBlockWithWrongPreviousBatchHash() public {
        bytes memory correctL2Logs = abi.encodePacked(
            bytes4(0x00000001),
            bytes4(0x00000000),
            L2_SYSTEM_CONTEXT_ADDRESS,
            Utils.packBatchTimestampAndBlockTimestamp(currentTimestamp, currentTimestamp),
            bytes32("")
        );

        IExecutor.CommitBatchInfo memory correctNewCommitBatchInfo = newCommitBatchInfo;
        correctNewCommitBatchInfo.systemLogs = correctL2Logs;

        IExecutor.CommitBatchInfo[] memory correctNewCommitBatchInfoArray = new IExecutor.CommitBatchInfo[](1);
        correctNewCommitBatchInfoArray[0] = correctNewCommitBatchInfo;

        IExecutor.HeaderUpdate[] memory headerArray = new IExecutor.HeaderUpdate[](1);
        headerArray[0] = Header;

        bytes32 wrongPreviousBatchHash = Utils.randomBytes32("wrongPreviousBatchHash");

        IExecutor.StoredBatchInfo memory genesisBlock = genesisStoredBatchInfo;
        genesisBlock.batchHash = wrongPreviousBatchHash;



        vm.prank(validator);
        vm.expectRevert(bytes.concat("i"));
        executor.commitBatches(genesisBlock, correctNewCommitBatchInfoArray, headerArray);
    }

    function test_ShouldExecuteBatchesuccessfully() public {
        IExecutor.StoredBatchInfo[] memory storedBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        storedBatchInfoArray[0] = newStoredBatchInfo;

        vm.prank(validator);
        executor.executeBatches(storedBatchInfoArray);

        uint256 totalBlocksExecuted = getters.getTotalBlocksExecuted();
        assertEq(totalBlocksExecuted, 1);
    }
}
