/**
 * @description Batch Apex class to associate eligible Opportunities with a Gift Aid Claim record.
 *              Supports both scoped execution (targeted to a specific claim) and bulk execution
 *              (matching opportunities across all active claims dynamically).
 */
public with sharing class GiftAidClaimPopulatorBatch implements Database.Batchable<sObject>, Database.Stateful {

    private final Id targetClaimId;
    private final String queryString;
    private List<GiftAidClaim__c> claims;
    private Integer totalProcessed = 0;
    private Integer totalFailed = 0;

    /**
     * @description Scoped constructor with custom query for a designated Gift Aid Claim.
     * @param targetClaimId Target GiftAidClaim__c record ID.
     * @param queryString The SOQL query string to drive batch chunks.
     */
    public GiftAidClaimPopulatorBatch(Id targetClaimId, String queryString) {
        if (targetClaimId == null) {
            throw new IllegalArgumentException('Gift Aid Claim ID cannot be null.');
        }
        if (String.isBlank(queryString)) {
            throw new IllegalArgumentException('Query string cannot be blank.');
        }
        this.targetClaimId = targetClaimId;
        this.queryString = queryString;
    }

    /**
     * @description Scoped constructor targeting a specific claim using its date boundaries.
     * @param targetClaimId Target GiftAidClaim__c record ID.
     */
    public GiftAidClaimPopulatorBatch(Id targetClaimId) {
        this(targetClaimId, GiftAidOpportunityService.buildOpportunityQueryForClaim(targetClaimId, false));
    }

    /**
     * @description Bulk constructor accepting a custom SOQL query string.
     * @param queryString The SOQL query string to drive batch chunks.
     */
    public GiftAidClaimPopulatorBatch(String queryString) {
        if (String.isBlank(queryString)) {
            throw new IllegalArgumentException('Query string cannot be blank.');
        }
        this.targetClaimId = null;
        this.queryString = queryString;
    }

    /**
     * @description Default bulk constructor querying all eligible unassigned Opportunities.
     */
    public GiftAidClaimPopulatorBatch() {
        this(GiftAidOpportunityService.buildOpportunityQuery(false));
    }

    /**
     * @description Database.Batchable start method
     * @param bc Batchable context.
     * @return Database.QueryLocator driving the batch scope.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (this.targetClaimId == null) {
            this.claims = GiftAidOpportunityService.getActiveClaims();
        }
        return Database.getQueryLocator(this.queryString);
    }

    /**
     * @description Database.Batchable execute method
     * @param bc Batchable context.
     * @param scope List of Opportunity records in the current batch chunk.
     */
    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        if (this.targetClaimId == null && this.claims == null) {
            this.claims = GiftAidOpportunityService.getActiveClaims();
        }

        List<Opportunity> validOpportunities = GiftAidOpportunityService.filterOpportunitiesWithValidAddress(scope);
        if (validOpportunities.isEmpty()) {
            return;
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity opp : validOpportunities) {
            Id matchingClaimId = (this.targetClaimId != null)
                ? this.targetClaimId
                : GiftAidOpportunityService.findMatchingClaimId(opp.CloseDate, this.claims);
            if (matchingClaimId != null && opp.GiftAidClaim__c != matchingClaimId) {
                oppsToUpdate.add(new Opportunity(
                    Id = opp.Id,
                    GiftAidClaim__c = matchingClaimId
                ));
            }
        }

        if (oppsToUpdate.isEmpty()) {
            return;
        }

        Database.SaveResult[] results = Database.update(oppsToUpdate, false, AccessLevel.USER_MODE);
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                this.totalProcessed++;
            } else {
                this.totalFailed++;
                for (Database.Error err : sr.getErrors()) {
                    System.debug(LoggingLevel.ERROR, 'Failed to link Opportunity (' + sr.getId() + '): ' + err.getMessage());
                }
            }
        }
    }

    /**
     * @description Database.Batchable finish method
     * @param bc Batchable context.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(
            LoggingLevel.INFO,
            'GiftAidClaimPopulatorBatch completed. Success: ' + this.totalProcessed + ', Failed: ' + this.totalFailed
        );
    }
}