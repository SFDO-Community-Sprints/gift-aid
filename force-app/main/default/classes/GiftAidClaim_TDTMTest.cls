@IsTest
private class GiftAidClaim_TDTMTest {

    @TestSetup
    static void setupTestData() {
        // Register the TDTM Trigger Handler so NPSP routes trigger execution to GiftAidClaim_TDTM
        insert new npsp__Trigger_Handler__c(
            Name = 'GiftAidClaim_TDTM',
            npsp__Class__c = 'GiftAidClaim_TDTM',
            npsp__Object__c = 'GiftAidClaim__c',
            npsp__Trigger_Action__c = 'AfterInsert;AfterUpdate',
            npsp__Active__c = true,
            npsp__Load_Order__c = 1,
            npsp__User_Managed__c = true
        );

        Contact donor = new Contact(
            FirstName = 'Test',
            LastName = 'Donor',
            MailingStreet = '10 Downing Street\nLondon',
            MailingPostalCode = 'SW1A 2AA'
        );
        insert donor;

        GiftAidCoveragePeriod__c period = new GiftAidCoveragePeriod__c(
            Contact__c = donor.Id,
            StartDate__c = Date.today().addYears(-1),
            EndDate__c = Date.today().addYears(1)
        );
        insert period;

        insert new Opportunity(
            Name = 'Claim Test Donation',
            StageName = 'Closed Won',
            CloseDate = Date.today().addMonths(-1),
            Amount = 100.00,
            npsp__Primary_Contact__c = donor.Id,
            GiftAidCoveragePeriod__c = period.Id,
            isGiftAidEligible__c = true
        );
    }

    @IsTest
    static void testAfterInsertWithAutoLinkEnabled() {
        Test.startTest();
        GiftAidClaim__c claim = new GiftAidClaim__c(
            ClaimStartDate__c = Date.today().addMonths(-2),
            ClaimEndDate__c = Date.today(),
            AutoLinkDonations__c = true
        );
        insert claim;
        Test.stopTest();

        Opportunity updatedOpp = [SELECT GiftAidClaim__c FROM Opportunity WHERE Name = 'Claim Test Donation'];
        System.assertEquals(claim.Id, updatedOpp.GiftAidClaim__c, 'Opportunity should be linked to the claim.');
    }

    @IsTest
    static void testAfterInsertWithAutoLinkDisabled() {
        Test.startTest();
        GiftAidClaim__c claim = new GiftAidClaim__c(
            ClaimStartDate__c = Date.today().addMonths(-2),
            ClaimEndDate__c = Date.today(),
            AutoLinkDonations__c = false
        );
        insert claim;
        Test.stopTest();

        Opportunity opp = [SELECT GiftAidClaim__c FROM Opportunity WHERE Name = 'Claim Test Donation'];
        System.assertEquals(null, opp.GiftAidClaim__c, 'Opportunity should not be linked when flag is false.');
    }

    @IsTest
    static void testAfterUpdateDateChange() {
        GiftAidClaim__c claim = new GiftAidClaim__c(
            ClaimStartDate__c = Date.today().addMonths(-5),
            ClaimEndDate__c = Date.today().addMonths(-3),
            AutoLinkDonations__c = true
        );
        insert claim;

        GiftAidClaimService.resetProcessedClaimIds();

        Test.startTest();
        claim.ClaimStartDate__c = Date.today().addMonths(-2);
        claim.ClaimEndDate__c = Date.today();
        update claim;
        Test.stopTest();

        Opportunity opp = [SELECT GiftAidClaim__c FROM Opportunity WHERE Name = 'Claim Test Donation'];
        System.assertEquals(claim.Id, opp.GiftAidClaim__c, 'Opportunity should be linked when dates change.');
    }

    @IsTest
    static void testAfterUpdateCheckboxToggled() {
        GiftAidClaim__c claim = new GiftAidClaim__c(
            ClaimStartDate__c = Date.today().addMonths(-2),
            ClaimEndDate__c = Date.today(),
            AutoLinkDonations__c = false
        );
        insert claim;

        GiftAidClaimService.resetProcessedClaimIds();

        Test.startTest();
        claim.AutoLinkDonations__c = true;
        update claim;
        Test.stopTest();

        Opportunity opp = [SELECT GiftAidClaim__c FROM Opportunity WHERE Name = 'Claim Test Donation'];
        System.assertEquals(claim.Id, opp.GiftAidClaim__c, 'Opportunity should be linked when checkbox turns on.');
    }

    @IsTest
    static void testQueueableExecution() {
        GiftAidClaim__c claim = new GiftAidClaim__c(
            ClaimStartDate__c = Date.today().addMonths(-2),
            ClaimEndDate__c = Date.today()
        );
        insert claim;

        Test.startTest();
        System.enqueueJob(new GiftAidClaimBatchQueueable(new Set<Id>{ claim.Id }));
        Test.stopTest();
    }
}