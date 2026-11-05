/**
 * @description Service class providing SOQL queries, data filtering, and validation
 *              for Gift Aid eligible Opportunities and Claim date matching.
 *              Reusable across triggers, batch classes, and synchronous services.
 */
public with sharing class GiftAidOpportunityService {

    /**
     * @description Constructs the dynamic SOQL query string for retrieving eligible Opportunities
     *              without requiring pre-selected claim IDs or date boundaries.
     * @param overwriteExisting If false, only queries records where GiftAidClaim__c is null.
     * @return Fully formatted SOQL query string.
     */
    public static String buildOpportunityQuery(Boolean overwriteExisting) {
        String queryString = 'SELECT Id, Name, CloseDate, GiftAidClaim__c, ' +
                             'npsp__Primary_Contact__c, ' +
                             'npsp__Primary_Contact__r.MailingStreet, ' +
                             'npsp__Primary_Contact__r.MailingPostalCode ' +
                             'FROM Opportunity ' +
                             'WHERE isGiftAidEligible__c = true ' +
                             'AND GiftAidCoveragePeriod__c != null ' +
                             'AND npsp__Primary_Contact__c != null ' +
                             'AND npsp__Primary_Contact__r.MailingStreet != null ' +
                             'AND npsp__Primary_Contact__r.MailingPostalCode != null';

        if (overwriteExisting == null || !overwriteExisting) {
            queryString += ' AND GiftAidClaim__c = null';
        }

        return queryString;
    }

    /**
     * @description Overloaded query builder providing optional date boundary filtering.
     * @param startDate Earliest CloseDate inclusive (optional).
     * @param endDate Latest CloseDate inclusive (optional).
     * @param overwriteExisting If false, only queries records where GiftAidClaim__c is null.
     * @return Fully formatted SOQL query string.
     */
    public static String buildOpportunityQuery(Date startDate, Date endDate, Boolean overwriteExisting) {
        String queryString = buildOpportunityQuery(overwriteExisting);

        if (startDate != null) {
            queryString += ' AND CloseDate >= ' + String.valueOf(startDate);
        }
        if (endDate != null) {
            queryString += ' AND CloseDate <= ' + String.valueOf(endDate);
        }

        return queryString;
    }

    /**
     * @description Fetches eligible Opportunities using standard criteria.
     *              Can be directly invoked from triggers or controller classes.
     * @param overwriteExisting If false, targets only unassigned Opportunities.
     * @return List of qualifying Opportunity records.
     */
    public static List<Opportunity> getEligibleOpportunities(Boolean overwriteExisting) {
        String queryString = buildOpportunityQuery(overwriteExisting);
        return Database.query(queryString, AccessLevel.USER_MODE);
    }

    /**
     * @description Retrieves the date boundaries from a GiftAidClaim__c record
     *              and builds the corresponding scoped Opportunity query string.
     * @param claimId Record ID of the target GiftAidClaim__c.
     * @param overwriteExisting If false, targets only unassigned Opportunities.
     * @return Formatted SOQL query string.
     */
    public static String buildOpportunityQueryForClaim(Id claimId, Boolean overwriteExisting) {
        if (claimId == null) {
            throw new IllegalArgumentException('Gift Aid Claim ID cannot be null.');
        }

        GiftAidClaim__c claim = [
            SELECT Id, ClaimStartDate__c, ClaimEndDate__c
            FROM GiftAidClaim__c
            WHERE Id = :claimId
            WITH USER_MODE
            LIMIT 1
        ];

        if (claim.ClaimStartDate__c == null) {
            throw new IllegalArgumentException('ClaimStartDate__c must be specified on the Gift Aid Claim record.');
        }

        Date effectiveEndDate = (claim.ClaimEndDate__c != null) ? claim.ClaimEndDate__c : Date.today();
        return buildOpportunityQuery(claim.ClaimStartDate__c, effectiveEndDate, overwriteExisting);
    }

    /**
     * @description Retrieves all active Gift Aid Claims with populated start dates,
     *              ordered by start date descending.
     * @return List of GiftAidClaim__c records.
     */
    public static List<GiftAidClaim__c> getActiveClaims() {
        return [
            SELECT Id, ClaimStartDate__c, ClaimEndDate__c
            FROM GiftAidClaim__c
            WHERE ClaimStartDate__c != null
            WITH USER_MODE
            ORDER BY ClaimStartDate__c DESC
        ];
    }

    /**
     * @description Matches an Opportunity's CloseDate against a list of Gift Aid Claims.
     *              A claim matches if ClaimStartDate__c <= CloseDate <= (ClaimEndDate__c ?? TODAY).
     * @param closeDate The CloseDate of the Opportunity.
     * @param claims List of available GiftAidClaim__c records.
     * @return Matching GiftAidClaim__c Id, or null if no claim range covers the close date.
     */
    public static Id findMatchingClaimId(Date closeDate, List<GiftAidClaim__c> claims) {
        if (closeDate == null || claims == null || claims.isEmpty()) {
            return null;
        }

        for (GiftAidClaim__c claim : claims) {
            Date effectiveEndDate = (claim.ClaimEndDate__c != null) ? claim.ClaimEndDate__c : Date.today();
            if (claim.ClaimStartDate__c != null &&
                closeDate >= claim.ClaimStartDate__c &&
                closeDate <= effectiveEndDate) {
                return claim.Id;
            }
        }
        return null;
    }

    /**
     * @description Filters a list of Opportunities, returning only those whose Primary Contact
     *              has a populated postal code and a non-blank first line in their mailing street.
     * @param opportunities List of Opportunity records with Contact relationship fields queried.
     * @return List of Opportunities meeting the mailing address criteria.
     */
    public static List<Opportunity> filterOpportunitiesWithValidAddress(List<Opportunity> opportunities) {
        List<Opportunity> validOpportunities = new List<Opportunity>();
        if (opportunities == null || opportunities.isEmpty()) {
            return validOpportunities;
        }

        for (Opportunity opp : opportunities) {
            if (hasValidMailingAddress(opp)) {
                validOpportunities.add(opp);
            }
        }
        return validOpportunities;
    }

    /**
     * @description Evaluates whether an Opportunity's Primary Contact has a valid Gift Aid address.
     * @param opp Opportunity record including npsp__Primary_Contact__r relationship.
     * @return True if postal code is non-blank and the first street line contains non-whitespace text.
     */
    public static Boolean hasValidMailingAddress(Opportunity opp) {
        String street = opp?.npsp__Primary_Contact__r?.MailingStreet;
        String postalCode = opp?.npsp__Primary_Contact__r?.MailingPostalCode;
        return String.isNotBlank(street) && String.isNotBlank(postalCode) && String.isNotBlank(street.split('\n')[0].trim());
    }

    /**
     * @description Enqueues GiftAidClaimPopulatorBatch in scoped mode for a single claim.
     *              Callable from LWC Quick Actions and triggers.
     * @param claimId Target GiftAidClaim__c record ID.
     * @return Id of the enqueued AsyncApexJob.
     */
    @AuraEnabled
    public static Id executeBatchForClaim(Id claimId) {
        if (claimId == null) {
            throw new AuraHandledException('Gift Aid Claim ID cannot be null.');
        }
        try {
            GiftAidClaimPopulatorBatch batchJob = new GiftAidClaimPopulatorBatch(claimId);
            return Database.executeBatch(batchJob, 200);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /**
     * @description Enqueues GiftAidClaimPopulatorBatch in global bulk mode across all active claims.
     * @return Id of the enqueued AsyncApexJob.
     */
    @AuraEnabled
    public static Id executeBatchBulk() {
        GiftAidClaimPopulatorBatch batchJob = new GiftAidClaimPopulatorBatch();
        return Database.executeBatch(batchJob, 200);
    }
}