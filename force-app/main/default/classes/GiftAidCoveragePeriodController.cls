/**
 * @description Supplies record-level access information for the giftAidCard LWC's Periods tab.
 *              Object- and field-level permissions are read in the LWC via getObjectInfo
 *              (lightning/uiObjectInfoApi); this class only answers the record-level question
 *              ("can the running user edit/delete this record?"), which no wire adapter exposes.
 *              Gift Aid Coverage Periods are master-detail children of Contact, so creating a
 *              period requires edit access to the parent Contact, while editing or deleting an
 *              existing period is governed by the period record's own access.
 */
public with sharing class GiftAidCoveragePeriodController {
    @TestVisible
    private static final Integer MAX_PERIOD_IDS = 199;
    @TestVisible
    private static final String ACCESS_ERROR_MESSAGE = 'Unable to determine your access to Gift Aid records. Please contact your administrator.';
    @TestVisible
    private static Boolean forceAccessCheckFailure = false;
    private class AccessCheckException extends Exception {}

    /**
     * @description Record-level access of the running user for a parent Contact and its periods.
     */
    public class PeriodRecordAccess {
        @AuraEnabled public Boolean contactEditable = false;
        @AuraEnabled public List<Id> editablePeriodIds = new List<Id>();
        @AuraEnabled public List<Id> deletablePeriodIds = new List<Id>();
    }

    /**
     * @description Returns the running user's record-level access to a Contact and a set of its
     *              Gift Aid Coverage Periods.
     * @param contactId The parent Contact Id.
     * @param periodIds Ids of the Gift Aid Coverage Periods displayed for that Contact. Only the first
     *                  MAX_PERIOD_IDS are checked; any beyond that are reported as not editable/deletable.
     * @return PeriodRecordAccess describing which records the user can edit and delete.
     * @throws AuraHandledException If access cannot be determined (generic message; details are logged).
     */
    @AuraEnabled
    public static PeriodRecordAccess getRecordAccess(Id contactId, List<Id> periodIds) {
        PeriodRecordAccess result = new PeriodRecordAccess();
        if (contactId == null) {
            return result;
        }

        Set<Id> recordIds = new Set<Id>{ contactId };
        if (periodIds != null) {
            for (Id periodId : periodIds) {
                if (periodId != null && recordIds.size() <= MAX_PERIOD_IDS) {
                    recordIds.add(periodId);
                }
            }
        }

        try {
            if (Test.isRunningTest() && forceAccessCheckFailure) {
                throw new AccessCheckException('Simulated access check failure');
            }
            for (UserRecordAccess access : [
                SELECT RecordId, HasEditAccess, HasDeleteAccess
                FROM UserRecordAccess
                WHERE UserId = :UserInfo.getUserId() AND RecordId IN :recordIds
                WITH USER_MODE
            ]) {
                if (access.RecordId == contactId) {
                    result.contactEditable = access.HasEditAccess;
                } else {
                    if (access.HasEditAccess) {
                        result.editablePeriodIds.add(access.RecordId);
                    }
                    if (access.HasDeleteAccess) {
                        result.deletablePeriodIds.add(access.RecordId);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'GiftAidCoveragePeriodController.getRecordAccess failed: '
                + e.getMessage() + '\n' + e.getStackTraceString());
            AuraHandledException auraException = new AuraHandledException(ACCESS_ERROR_MESSAGE);
            auraException.setMessage(ACCESS_ERROR_MESSAGE);
            throw auraException;
        }
        return result;
    }
}
