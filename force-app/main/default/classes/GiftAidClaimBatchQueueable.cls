/**
 * @description Standalone Queueable class to chain and enqueue Gift Aid Claim batch jobs safely in asynchronous contexts.
 */
public with sharing class GiftAidClaimBatchQueueable implements Queueable {
    private List<Id> claimIds;

    /**
     * @description Constructor accepting the set of Gift Aid Claim record IDs to process.
     * @param claimIds Set of GiftAidClaim__c record IDs.
     */
    public GiftAidClaimBatchQueueable(Set<Id> claimIds) {
        this.claimIds = (claimIds != null) ? new List<Id>(claimIds) : new List<Id>();
    }

    /**
     * @description Constructor accepting the list of Gift Aid Claim record IDs to process.
     * @param claimIds List of GiftAidClaim__c record IDs.
     */
    public GiftAidClaimBatchQueueable(List<Id> claimIds) {
        this.claimIds = (claimIds != null) ? new List<Id>(claimIds) : new List<Id>();
    }

    /**
     * @description Executes the queueable job by running one batch job at a time and chaining the remainder.
     * @param context Queueable execution context.
     */
    public void execute(QueueableContext context) {
        if (this.claimIds == null || this.claimIds.isEmpty()) {
            return;
        }

        Id claimId = this.claimIds.remove(0);
        GiftAidOpportunityService.executeBatchForClaim(claimId);

        if (!this.claimIds.isEmpty() && !Test.isRunningTest() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new GiftAidClaimBatchQueueable(this.claimIds));
        }
    }
}