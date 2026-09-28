trigger CustomerProductMappingTrigger on Customer_Product_Mapping__c (
    before insert,
    before update,
    after insert,
    after update
) {
    CustomerProductMappingHandler handler = new CustomerProductMappingHandler();
    handler.run(Trigger.new, Trigger.old, Trigger.operationType);
}