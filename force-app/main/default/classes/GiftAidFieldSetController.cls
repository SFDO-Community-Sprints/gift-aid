public with sharing class GiftAidFieldSetController {
    
    /**
     * Dynamically reads field API names from a specified Contact Field Set.
     * @param fieldSetName The developer API name of the target Field Set.
     * @return List of strings representing field API names.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getFieldSetFields(String fieldSetName) {
        List<String> fieldApiNames = new List<String>();
        
        try {
            if (String.isBlank(fieldSetName)) {
                return fieldApiNames;
            }

            // Fetch the FieldSet map dynamically from the Contact SObject token
            Map<String, Schema.FieldSet> fieldSetMap = Schema.SObjectType.Contact.fieldSets.getMap();
            Schema.FieldSet fs = fieldSetMap.get(fieldSetName);
            
            if (fs != null) {
                for (Schema.FieldSetMember f : fs.getFields()) {
                    fieldApiNames.add(f.getFieldPath());
                }
            } else {
                throw new AuraHandledException('The Field Set "' + fieldSetName + '" was not found on the Contact object.');
            }
        } catch (Exception e) {
            throw new AuraHandledException('Package error processing Field Set metadata: ' + e.getMessage());
        }
        
        return fieldApiNames;
    }
}