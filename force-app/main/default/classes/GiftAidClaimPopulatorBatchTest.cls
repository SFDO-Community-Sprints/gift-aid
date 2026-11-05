@IsTest
private class GiftAidClaimPopulatorBatchTest {

    @TestSetup
    static void setupTestData() {
        Contact donorWithInvalidAddress = new Contact(
            FirstName = 'John',
            LastName = 'NoStreet',
            MailingStreet = null,
            MailingPostalCode = null
        );
        insert donorWithInvalidAddress;

        Contact donor = new Contact(
            FirstName = 'Jane',
            LastName = 'Doe',
            MailingStreet = '10 Downing Street\nWestminster',
            MailingPostalCode = 'SW1A 2AA'
        );
        insert donor;

        GiftAidCoveragePeriod__c period = new GiftAidCoveragePeriod__c(
            Contact__c = donor.Id,
            StartDate__c = Date.today().addYears(-1),
            EndDate__c = Date.today().addYears(1)
        );
        insert period;

        GiftAidClaim__c claim = new GiftAidClaim__c(
            ClaimStartDate__c = Date.today().addMonths(-2),
            ClaimEndDate__c = Date.today()
        );
        insert claim;

        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(
                Name = 'Eligible Donation',
                StageName = 'Closed Won',
                CloseDate = Date.today().addMonths(-1),
                Amount = 100.00,
                npsp__Primary_Contact__c = donor.Id,
                GiftAidCoveragePeriod__c = period.Id,
                isGiftAidEligible__c = true
            ),
            new Opportunity(
                Name = 'Out of Date Donation',
                StageName = 'Closed Won',
                CloseDate = Date.today().addMonths(-4),
                Amount = 50.00,
                npsp__Primary_Contact__c = donor.Id,
                GiftAidCoveragePeriod__c = period.Id,
                isGiftAidEligible__c = true
            ),
            new Opportunity(
                Name = 'Invalid Address Donation',
                StageName = 'Closed Won',
                CloseDate = Date.today().addMonths(-1),
                Amount = 75.00,
                npsp__Primary_Contact__c = donorWithInvalidAddress.Id,
                GiftAidCoveragePeriod__c = period.Id,
                isGiftAidEligible__c = true
            )
        };
        insert opps;
    }

    @IsTest
    static void testBulkBatchExecution() {
        GiftAidClaim__c claim = [SELECT Id FROM GiftAidClaim__c LIMIT 1];

        Test.startTest();
        GiftAidClaimPopulatorBatch batch = new GiftAidClaimPopulatorBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Opportunity updatedOpp = [
            SELECT Id, GiftAidClaim__c
            FROM Opportunity
            WHERE Name = 'Eligible Donation'
        ];
        System.assertEquals(claim.Id, updatedOpp.GiftAidClaim__c, 'Eligible opportunity must be linked to the claim.');

        Opportunity unlinkedOpp = [
            SELECT Id, GiftAidClaim__c
            FROM Opportunity
            WHERE Name = 'Out of Date Donation'
        ];
        System.assertEquals(null, unlinkedOpp.GiftAidClaim__c, 'Out of bounds opportunity should not be linked.');

        Opportunity invalidAddressOpp = [
            SELECT Id, GiftAidClaim__c
            FROM Opportunity
            WHERE Name = 'Invalid Address Donation'
        ];
        System.assertEquals(null, invalidAddressOpp.GiftAidClaim__c, 'Opportunity with invalid address must not be linked.');
    }

    @IsTest
    static void testScopedBatchExecutionViaService() {
        GiftAidClaim__c claim = [SELECT Id FROM GiftAidClaim__c LIMIT 1];

        Test.startTest();
        Id jobId = GiftAidOpportunityService.executeBatchForClaim(claim.Id);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job ID should be returned from scoped execution.');

        Opportunity updatedOpp = [
            SELECT Id, GiftAidClaim__c
            FROM Opportunity
            WHERE Name = 'Eligible Donation'
        ];
        System.assertEquals(claim.Id, updatedOpp.GiftAidClaim__c, 'Eligible opportunity must be linked to the claim.');

        Opportunity unlinkedOpp = [
            SELECT Id, GiftAidClaim__c
            FROM Opportunity
            WHERE Name = 'Out of Date Donation'
        ];
        System.assertEquals(null, unlinkedOpp.GiftAidClaim__c, 'Out of bounds opportunity should not be linked.');
    }

    @IsTest
    static void testBulkBatchServiceExecution() {
        Test.startTest();
        Id jobId = GiftAidOpportunityService.executeBatchBulk();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job ID should be returned from bulk execution.');
    }

    @IsTest
    static void testServiceMethodsAndMatching() {
        GiftAidClaim__c claim = [SELECT Id FROM GiftAidClaim__c LIMIT 1];

        List<Opportunity> fetchedOpps = GiftAidOpportunityService.getEligibleOpportunities(false);
        System.assertNotEquals(0, fetchedOpps.size(), 'Service query must return eligible opportunities.');

        List<GiftAidClaim__c> claims = GiftAidOpportunityService.getActiveClaims();
        System.assertNotEquals(0, claims.size(), 'Should find active Gift Aid Claim records.');

        Id matchedClaimId = GiftAidOpportunityService.findMatchingClaimId(Date.today().addMonths(-1), claims);
        System.assertEquals(claim.Id, matchedClaimId, 'CloseDate within range should match active claim ID.');

        String claimQuery = GiftAidOpportunityService.buildOpportunityQueryForClaim(claim.Id, false);
        System.assert(claimQuery.contains('CloseDate'), 'Query should include CloseDate boundaries.');

        List<Opportunity> addressFilteredOpps = GiftAidOpportunityService.filterOpportunitiesWithValidAddress(fetchedOpps);
        for (Opportunity opp : addressFilteredOpps) {
            System.assertNotEquals('Invalid Address Donation', opp.Name, 'Opportunities with invalid street should be excluded.');
        }

        // In-memory address validation verifying blank first street line behavior
        Contact blankLineContact = new Contact(
            MailingStreet = '   \nWestminster',
            MailingPostalCode = 'SW1A 2AA'
        );
        Opportunity blankLineOpp = new Opportunity(
            Name = 'Blank Line Test Opp',
            npsp__Primary_Contact__r = blankLineContact
        );
        System.assertEquals(
            false,
            GiftAidOpportunityService.hasValidMailingAddress(blankLineOpp),
            'Primary Contact with blank first line of street should not be valid.'
        );
        System.assertEquals(
            0,
            GiftAidOpportunityService.filterOpportunitiesWithValidAddress(new List<Opportunity>{ blankLineOpp }).size(),
            'Opportunities with blank first line of street should be filtered out.'
        );
    }

    @IsTest
    static void testBatchConstructorValidations() {
        try {
            new GiftAidClaimPopulatorBatch('');
            System.assert(false, 'Should throw IllegalArgumentException when query is blank.');
        } catch (IllegalArgumentException ex) {
            System.assert(ex.getMessage().contains('Query string'), 'Expected query validation error.');
        }

        try {
            new GiftAidClaimPopulatorBatch((Id) null);
            System.assert(false, 'Should throw IllegalArgumentException when claimId is null.');
        } catch (IllegalArgumentException ex) {
            System.assert(ex.getMessage().contains('Gift Aid Claim ID'), 'Expected claim ID validation error.');
        }

        try {
            GiftAidOpportunityService.executeBatchForClaim(null);
            System.assert(false, 'Should throw AuraHandledException when claimId is null.');
        } catch (AuraHandledException ex) {
            System.assert(true, 'Expected AuraHandledException.');
        }
    }
}