trigger TDTM_GiftAidClaimTrigger on GiftAidClaim__c (before insert, before update, after insert, after update) {
    
   npsp.TDTM_Config_API.run(Trigger.isBefore, Trigger.isAfter, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete, Trigger.isUndelete, Trigger.new, Trigger.old, Schema.SObjectType.GiftAidClaim__c);

}