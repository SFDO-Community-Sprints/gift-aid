/**
 * @description TDTM handler class for GiftAidClaim__c.
 *              Handles AfterInsert and AfterUpdate to trigger automatic donation linking.
 */
global with sharing class GiftAidClaim_TDTM extends npsp.TDTM_Runnable {

    /**
     * @description Core execution method called by the NPSP TDTM framework.
     * @param listNew List of new records from trigger context.
     * @param listOld List of old records from trigger context.
     * @param triggerAction Trigger action (AfterInsert, AfterUpdate, etc.).
     * @param objResult Describe result for GiftAidClaim__c.
     * @return DmlWrapper containing records for DML processing.
     */
    global override npsp.TDTM_Runnable.DmlWrapper run(
        List<SObject> listNew,
        List<SObject> listOld,
        npsp.TDTM_Runnable.Action triggerAction,
        Schema.DescribeSObjectResult objResult
    ) {
        if (triggerAction == npsp.TDTM_Runnable.Action.AfterInsert) {
            GiftAidClaimService.handleAfterInsert((List<GiftAidClaim__c>) listNew);
        } else if (triggerAction == npsp.TDTM_Runnable.Action.AfterUpdate) {
            GiftAidClaimService.handleAfterUpdate(
                (List<GiftAidClaim__c>) listNew,
                new Map<Id, GiftAidClaim__c>((List<GiftAidClaim__c>) listOld)
            );
        }

        return new npsp.TDTM_Runnable.DmlWrapper();
    }
}