// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ExecutorTest} from "./_Executor_Shared.t.sol";
import {Utils} from "../Utils/Utils.sol";
import {IExecutor} from "../../../../../cache/solpp-generated-contracts/zksync/interfaces/IExecutor.sol";

contract AuthorizationTest is ExecutorTest {
    IExecutor.StoredBatchInfo private storedBatchInfo;
    IExecutor.CommitBatchInfo private commitBatchInfo;
    IExecutor.HeaderUpdate private nHeader;

    function setUp() public {
        //Inital Header Value
        bytes32[] memory emptyArray;
        nHeader = IExecutor.HeaderUpdate({
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

        storedBatchInfo = IExecutor.StoredBatchInfo({
            batchNumber: 0,
            batchHash: Utils.randomBytes32("batchHash"),
            indexRepeatedStorageChanges: 0,
            numberOfLayer1Txs: 0,
            priorityOperationsHash: Utils.randomBytes32("priorityOperationsHash"),
            l2LogsTreeRoot: Utils.randomBytes32("l2LogsTreeRoot"),
            timestamp: 0,
            commitment: Utils.randomBytes32("commitment"),
            header: nHeader
        });

        commitBatchInfo = IExecutor.CommitBatchInfo({
            batchNumber: 0,
            timestamp: 0,
            indexRepeatedStorageChanges: 0,
            newStateRoot: Utils.randomBytes32("newStateRoot"),
            numberOfLayer1Txs: 0,
            priorityOperationsHash: Utils.randomBytes32("priorityOperationsHash"),
            bootloaderHeapInitialContentsHash: Utils.randomBytes32("bootloaderHeapInitialContentsHash"),
            eventsQueueStateHash: Utils.randomBytes32("eventsQueueStateHash"),
            systemLogs: bytes(""),
            pubdataCommitments: bytes("")
        });
    }

    function test_RevertWhen_CommitingByUnauthorisedAddress() public {
        IExecutor.CommitBatchInfo[] memory commitBatchInfoArray = new IExecutor.CommitBatchInfo[](1);
        commitBatchInfoArray[0] = commitBatchInfo;

        IExecutor.HeaderUpdate[] memory headerArray = new IExecutor.HeaderUpdate[](1);
        headerArray[0] = nHeader;

        vm.prank(randomSigner);

        vm.expectRevert(bytes.concat("1h"));
        executor.commitBatches(storedBatchInfo, commitBatchInfoArray, headerArray);
    }

    function test_RevertWhen_ProvingByUnauthorisedAddress() public {
        IExecutor.StoredBatchInfo[] memory storedBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        storedBatchInfoArray[0] = storedBatchInfo;

        vm.prank(owner);

        vm.expectRevert(bytes.concat("1h"));
        executor.proveBatches(storedBatchInfo, storedBatchInfoArray, proofInput);
    }

    function test_RevertWhen_ExecutingByUnauthorizedAddress() public {
        IExecutor.StoredBatchInfo[] memory storedBatchInfoArray = new IExecutor.StoredBatchInfo[](1);
        storedBatchInfoArray[0] = storedBatchInfo;

        vm.prank(randomSigner);

        vm.expectRevert(bytes.concat("1h"));
        executor.executeBatches(storedBatchInfoArray);
    }
}
