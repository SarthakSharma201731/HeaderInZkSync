// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Vm} from "forge-std/Test.sol";
import {ExecutorTest} from "./_Executor_Shared.t.sol";
import {Utils, L2_SYSTEM_CONTEXT_ADDRESS} from "../Utils/Utils.sol";
import {COMMIT_TIMESTAMP_NOT_OLDER} from "../../../../../cache/solpp-generated-contracts/zksync/Config.sol";
import {IExecutor, SystemLogKey} from "../../../../../cache/solpp-generated-contracts/zksync/interfaces/IExecutor.sol";

contract ProvingTest is ExecutorTest {
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

        newCommitBatchInfo.timestamp = uint64(currentTimestamp);
        newCommitBatchInfo.systemLogs = l2Logs;

        IExecutor.CommitBatchInfo[] memory commitBatchInfoArray = new IExecutor.CommitBatchInfo[](1);
        commitBatchInfoArray[0] = newCommitBatchInfo;

        IExecutor.HeaderUpdate[] memory headerArray = new IExecutor.HeaderUpdate[](1);
        headerArray[0] = Header;

        vm.prank(validator);
        vm.recordLogs();
        executor.commitBatches(genesisStoredBatchInfo, commitBatchInfoArray, headerArray);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        //Header Initialization
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
    }

    function test_RevertWhen_ProvingWithWrongPreviousBlockData() public {
        IExecutor.StoredBatchInfo memory wrongPreviousStoredBatchInfo = genesisStoredBatchInfo;
        wrongPreviousStoredBatchInfo.batchNumber = 10; // Correct is 0

        IExecutor.StoredBatchInfo[] memory storedBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        storedBatchInfoArray[0] = newStoredBatchInfo;

        vm.prank(validator);

        vm.expectRevert(bytes.concat("t1"));
        executor.proveBatches(wrongPreviousStoredBatchInfo, storedBatchInfoArray, proofInput);
    }

    function test_RevertWhen_ProvingWithWrongCommittedBlock() public {
        IExecutor.StoredBatchInfo memory wrongNewStoredBatchInfo = newStoredBatchInfo;
        wrongNewStoredBatchInfo.batchNumber = 10; // Correct is 1

        IExecutor.StoredBatchInfo[] memory storedBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        storedBatchInfoArray[0] = wrongNewStoredBatchInfo;

        vm.prank(validator);

        vm.expectRevert(bytes.concat("o1"));
        executor.proveBatches(genesisStoredBatchInfo, storedBatchInfoArray, proofInput);
    }

    function test_RevertWhen_ProvingRevertedBlockWithoutCommittingAgain() public {
        vm.prank(validator);
        executor.revertBatches(0);

        IExecutor.StoredBatchInfo[] memory storedBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        storedBatchInfoArray[0] = newStoredBatchInfo;

        vm.prank(validator);

        vm.expectRevert(bytes.concat("q"));
        executor.proveBatches(genesisStoredBatchInfo, storedBatchInfoArray, proofInput);
    }

    function test_SuccessfulProve() public {
        IExecutor.StoredBatchInfo[] memory storedBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        storedBatchInfoArray[0] = newStoredBatchInfo;

        vm.prank(validator);

        executor.proveBatches(genesisStoredBatchInfo, storedBatchInfoArray, proofInput);

        uint256 totalBlocksVerified = getters.getTotalBlocksVerified();
        assertEq(totalBlocksVerified, 1);
    }
}
