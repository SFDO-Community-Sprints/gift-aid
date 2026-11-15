/**
 * @description Tests for GiftAidCoveragePeriodController.
 */
@isTest
private class GiftAidCoveragePeriodControllerTest {

    /**
     * @description The record owner has edit and delete access to the Contact and its period.
     */
    @isTest
    static void testAccessForRecordOwner() {
        Contact c = new Contact(LastName = 'Coverage Access Test');
        insert c;
        GiftAidCoveragePeriod__c period = new GiftAidCoveragePeriod__c(
            Contact__c = c.Id,
            DeclarationDate__c = Date.today(),
            StartDate__c = Date.today()
        );
        insert period;

        Test.startTest();
        GiftAidCoveragePeriodController.PeriodRecordAccess access =
            GiftAidCoveragePeriodController.getRecordAccess(c.Id, new List<Id>{ period.Id });
        Test.stopTest();

        Assert.isTrue(access.contactEditable, 'Owner should be able to edit the Contact');
        Assert.isTrue(access.editablePeriodIds.contains(period.Id), 'Owner should be able to edit the period');
        Assert.isTrue(access.deletablePeriodIds.contains(period.Id), 'Owner should be able to delete the period');
    }

    /**
     * @description A Contact with no periods passed still returns Contact access.
     */
    @isTest
    static void testNullPeriodIds() {
        Contact c = new Contact(LastName = 'Coverage Access Test');
        insert c;

        Test.startTest();
        GiftAidCoveragePeriodController.PeriodRecordAccess access =
            GiftAidCoveragePeriodController.getRecordAccess(c.Id, null);
        Test.stopTest();

        Assert.isTrue(access.contactEditable, 'Owner should be able to edit the Contact');
        Assert.isTrue(access.editablePeriodIds.isEmpty(), 'No periods requested, so none should be returned');
    }

    /**
     * @description A user on the standard "Read Only" profile can at most view the records, so every
     *              flag must be false. Exercises the false branches and WITH USER_MODE on UserRecordAccess.
     */
    @isTest
    static void testReadOnlyUserGetsNoEditOrDelete() {
        Contact c = new Contact(LastName = 'Coverage Access Test');
        insert c;
        GiftAidCoveragePeriod__c period = new GiftAidCoveragePeriod__c(
            Contact__c = c.Id,
            DeclarationDate__c = Date.today(),
            StartDate__c = Date.today()
        );
        insert period;

        User readOnlyUser = createUser('Read Only');

        GiftAidCoveragePeriodController.PeriodRecordAccess access;
        Test.startTest();
        System.runAs(readOnlyUser) {
            access = GiftAidCoveragePeriodController.getRecordAccess(c.Id, new List<Id>{ period.Id });
        }
        Test.stopTest();

        Assert.isFalse(access.contactEditable, 'Read Only user must not be able to edit the Contact');
        Assert.isFalse(access.editablePeriodIds.contains(period.Id), 'Read Only user must not be able to edit the period');
        Assert.isFalse(access.deletablePeriodIds.contains(period.Id), 'Read Only user must not be able to delete the period');
    }

    /**
     * @description More period Ids than UserRecordAccess can check in one query are capped, not an error.
     */
    @isTest
    static void testPeriodIdsAreCapped() {
        Contact c = new Contact(LastName = 'Coverage Access Test');
        insert c;

        // Fake (non-existent) period Ids: no UserRecordAccess rows come back for them, but the query must not fail
        List<Id> periodIds = new List<Id>();
        String prefix = GiftAidCoveragePeriod__c.SObjectType.getDescribe().getKeyPrefix();
        for (Integer i = 0; i < GiftAidCoveragePeriodController.MAX_PERIOD_IDS + 50; i++) {
            periodIds.add(Id.valueOf(prefix + String.valueOf(i).leftPad(12, '0')));
        }

        Test.startTest();
        GiftAidCoveragePeriodController.PeriodRecordAccess access =
            GiftAidCoveragePeriodController.getRecordAccess(c.Id, periodIds);
        Test.stopTest();

        Assert.isTrue(access.contactEditable, 'Contact access should still be returned when the Id list is capped');
    }

    /**
     * @description No Contact means no access is granted.
     */
    @isTest
    static void testNullContactGrantsNothing() {
        Test.startTest();
        GiftAidCoveragePeriodController.PeriodRecordAccess access =
            GiftAidCoveragePeriodController.getRecordAccess(null, null);
        Test.stopTest();

        Assert.isFalse(access.contactEditable, 'No contact should mean no edit access');
        Assert.isTrue(access.editablePeriodIds.isEmpty(), 'No contact should mean no editable periods');
        Assert.isTrue(access.deletablePeriodIds.isEmpty(), 'No contact should mean no deletable periods');
    }

    /**
     * @description A failure while checking access surfaces as an AuraHandledException with a fixed,
     *              user-friendly message that does not leak the underlying error.
     */
    @isTest
    static void testFailureThrowsGenericAuraHandledException() {
        Contact c = new Contact(LastName = 'Coverage Access Test');
        insert c;
        GiftAidCoveragePeriodController.forceAccessCheckFailure = true;

        Test.startTest();
        try {
            GiftAidCoveragePeriodController.getRecordAccess(c.Id, null);
            Assert.fail('An AuraHandledException should have been thrown');
        } catch (AuraHandledException e) {
            Assert.areEqual(GiftAidCoveragePeriodController.ACCESS_ERROR_MESSAGE, e.getMessage(),
                'The user should see the generic message');
            Assert.isFalse(e.getMessage().contains('Simulated'), 'The underlying error must not be leaked');
        }
        Test.stopTest();
    }

    private static User createUser(String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniqueName = 'gacp' + Crypto.getRandomInteger() + '@example.com.test';
        User u = new User(
            ProfileId = p.Id,
            Username = uniqueName,
            Email = uniqueName,
            LastName = 'Access Test',
            Alias = 'gacptest',
            TimeZoneSidKey = 'Europe/London',
            LocaleSidKey = 'en_GB',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }
}
