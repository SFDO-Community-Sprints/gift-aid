/**
 * @description Service class handling business logic and trigger orchestration for GiftAidClaim__c.
 */
public with sharing class GiftAidClaimService {

    // Guards against multiple executions in the same transaction
    private static Set<Id> processedClaimIds = new Set<Id>();

    /**
     * @description Evaluates newly inserted claims and triggers linking when criteria are met.
     * @param newClaims List of inserted GiftAidClaim__c records.
     */
    public static void handleAfterInsert(List<GiftAidClaim__c> newClaims) {
        if (newClaims == null || newClaims.isEmpty()) {
            return;
        }

        Set<Id> qualifyingClaimIds = new Set<Id>();
        for (GiftAidClaim__c claim : newClaims) {
            if (claim.AutoLinkDonations__c == true && claim.ClaimStartDate__c != null) {
                qualifyingClaimIds.add(claim.Id);
            }
        }

        processClaims(qualifyingClaimIds);
    }

    /**
     * @description Evaluates updated claims and triggers linking if dates or the auto-link flag changed.
     * @param newClaims List of updated GiftAidClaim__c records.
     * @param oldClaimsMap Map of old GiftAidClaim__c records by Id.
     */
    public static void handleAfterUpdate(List<GiftAidClaim__c> newClaims, Map<Id, GiftAidClaim__c> oldClaimsMap) {
        if (newClaims == null || newClaims.isEmpty() || oldClaimsMap == null) {
            return;
        }

        Set<Id> qualifyingClaimIds = new Set<Id>();
        for (GiftAidClaim__c claim : newClaims) {
            GiftAidClaim__c oldClaim = oldClaimsMap.get(claim.Id);
            if (claim.AutoLinkDonations__c == true && claim.ClaimStartDate__c != null) {
                Boolean startDateChanged = (oldClaim != null &&
                    claim.ClaimStartDate__c != oldClaim.ClaimStartDate__c &&
                    claim.ClaimStartDate__c != null);
                Boolean endDateChanged = (oldClaim != null &&
                    claim.ClaimEndDate__c != oldClaim.ClaimEndDate__c &&
                    claim.ClaimEndDate__c != null);
                Boolean checkboxTurnedOn = (oldClaim != null && oldClaim.AutoLinkDonations__c != true);

                if (startDateChanged || endDateChanged || checkboxTurnedOn) {
                    qualifyingClaimIds.add(claim.Id);
                }
            }
        }

        processClaims(qualifyingClaimIds);
    }

    /**
     * @description Coordinates batch execution asynchronously while protecting governor limits.
     * @param claimIds Set of GiftAidClaim__c record IDs to process.
     */
    public static void processClaims(Set<Id> claimIds) {
        if (claimIds == null || claimIds.isEmpty()) {
            return;
        }

        Set<Id> toProcess = new Set<Id>();
        for (Id claimId : claimIds) {
            if (claimId != null && !processedClaimIds.contains(claimId)) {
                toProcess.add(claimId);
                processedClaimIds.add(claimId);
            }
        }

        if (toProcess.isEmpty()) {
            return;
        }

        // If already in an asynchronous context (Batch/Future), delegate to Queueable to avoid runtime errors
        if (System.isBatch() || System.isFuture()) {
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(new GiftAidClaimBatchQueueable(toProcess));
            }
            return;
        }

        // Standard synchronous context: Enqueue batch jobs
        for (Id claimId : toProcess) {
            try {
                GiftAidOpportunityService.executeBatchForClaim(claimId);
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Failed to launch batch for claim ' + claimId + ': ' + ex.getMessage());
            }
        }
    }

    @TestVisible
    private static void resetProcessedClaimIds() {
        processedClaimIds.clear();
    }
}