/**
 * @description Asynchronous SKU validation for Customer_Product_Mapping__c.
 * Resolves PPI_SKU_Input__c against active Product2.StockKeepingUnit:
 *  - Valid:   Product__c populated, Status = Valid,   Is_Active = true
 *  - Invalid: Product__c = null,    Status = Invalid, Is_Active = false + Case
 * A Transaction Finalizer creates a Case on unhandled job failure.
 *
 * SKU resolution is case-insensitive. The Product2 SOQL filter is already
 * case-insensitive, but the in-memory Map<String, Id> lookup is case-sensitive,
 * so both the map key (Product2.StockKeepingUnit) and the lookup key
 * (PPI_SKU_Input__c) are upper-cased before comparison. This decouples
 * validation from how the SKU happens to be cased in the input or in storage,
 * preventing false "Invalid" results when casing differs.
 *
 * NOTE: queries and DML intentionally run in SYSTEM context. The class stamps
 * system-managed fields (Validation_Status__c, Is_Active__c, Product__c) that are
 * read-only at FLS level for portal users by design; record scope is constrained
 * to the explicit Id list received from the trigger.
 */
public without sharing class CustomerProductMappingQueueable
    implements Queueable, Finalizer {

    @TestVisible private static final String SUPPORT_REQUEST_QUEUE = 'Support Request';

    // Test seam: lets tests inject the SKU resolution map, decoupling them from
    // org-side automation/restrictions on Product2. Never used outside tests.
    // Keys are expected to be upper-cased SKUs (lookup normalizes to upper case).
    @TestVisible
    private static Map<String, Id> skuResolutionOverrideForTests;

    private List<Id> recordIds;

    public CustomerProductMappingQueueable(List<Id> recordIds) {
        this.recordIds = recordIds;
    }

    public void execute(QueueableContext context) {
        System.attachFinalizer(this);

        List<Customer_Product_Mapping__c> mappings = [
            SELECT Id, PPI_SKU_Input__c, Account__c
            FROM Customer_Product_Mapping__c
            WHERE Id IN :recordIds
        ];
        if (mappings.isEmpty()) {
            return;
        }

        // Single bulk validation query
        Set<String> skusToValidate = new Set<String>();
        for (Customer_Product_Mapping__c m : mappings) {
            if (String.isNotBlank(m.PPI_SKU_Input__c)) {
                skusToValidate.add(m.PPI_SKU_Input__c);
            }
        }

        Map<String, Id> skuToProductId;
        if (Test.isRunningTest() && skuResolutionOverrideForTests != null) {
            skuToProductId = skuResolutionOverrideForTests;
        } else {
            skuToProductId = new Map<String, Id>();
            for (Product2 p : [
                SELECT Id, StockKeepingUnit
                FROM Product2
                WHERE StockKeepingUnit IN :skusToValidate
                AND IsActive = true
            ]) {
                // Upper-case the key so the lookup is case-insensitive regardless
                // of how StockKeepingUnit is stored.
                if (String.isNotBlank(p.StockKeepingUnit)) {
                    skuToProductId.put(p.StockKeepingUnit.toUpperCase(), p.Id);
                }
            }
        }

        List<Customer_Product_Mapping__c> toUpdate =
            new List<Customer_Product_Mapping__c>();
        List<Customer_Product_Mapping__c> invalidRecords =
            new List<Customer_Product_Mapping__c>();

        for (Customer_Product_Mapping__c mapping : mappings) {
            Customer_Product_Mapping__c updated =
                new Customer_Product_Mapping__c(Id = mapping.Id);

            // Upper-case the lookup key to match the normalized map key.
            String skuKey = String.isBlank(mapping.PPI_SKU_Input__c)
                ? null
                : mapping.PPI_SKU_Input__c.toUpperCase();

            if (skuKey != null && skuToProductId.containsKey(skuKey)) {
                updated.Product__c = skuToProductId.get(skuKey);
                updated.Validation_Status__c = 'Valid';
                updated.Is_Active__c = true;
            } else {
                updated.Product__c = null;
                updated.Validation_Status__c = 'Invalid';
                updated.Is_Active__c = false;
                invalidRecords.add(mapping);
            }
            toUpdate.add(updated);
        }

        if (!toUpdate.isEmpty()) {
            // Suppress the handler's revalidation on this system-driven update,
            // otherwise records that remain Invalid would re-enqueue endlessly.
            CustomerProductMappingHandler.bypassRevalidation = true;
            try {
                Database.update(toUpdate, false); // partial success allowed
            } finally {
                CustomerProductMappingHandler.bypassRevalidation = false;
            }
        }
        if (!invalidRecords.isEmpty()) {
            createErrorCase(invalidRecords);
        }
    }

    // Finalizer: capture job-level unhandled exceptions
    public void execute(System.FinalizerContext ctx) {
        if (ctx != null
                && ctx.getResult() == System.ParentJobResult.UNHANDLED_EXCEPTION) {
            createErrorCase(new List<Customer_Product_Mapping__c>());
        }
    }

    @TestVisible
    private static void createErrorCase(List<Customer_Product_Mapping__c> invalidRecords) {
        Group supportQueue = getSupportRequestQueue();
        if (supportQueue == null) {
            return; // queue not configured; nothing to route the Case to
        }

        String description = invalidRecords.isEmpty()
            ? 'An unexpected error occurred during Customer Part Number background processing.'
            : buildInvalidRecordsDescription(invalidRecords);

        Case errorCase = new Case(
            Subject = 'Customer Part Number Upload - Validation Error',
            Description = description,
            OwnerId = supportQueue.Id,
            Origin = 'Web',
            Status = 'New'
        );
        insert errorCase;
    }

    private static Group getSupportRequestQueue() {
        List<Group> queues = [
            SELECT Id FROM Group
            WHERE Type = 'Queue' AND Name = :SUPPORT_REQUEST_QUEUE
            LIMIT 1
        ];
        return queues.isEmpty() ? null : queues[0];
    }

    private static String buildInvalidRecordsDescription(
        List<Customer_Product_Mapping__c> invalidRecords
    ) {
        String descriptionText = 'The following SKUs could not be validated:\n';
        for (Customer_Product_Mapping__c mapping : invalidRecords) {
            descriptionText += '- Account: ' + mapping.Account__c
                + ' | SKU Input: ' + mapping.PPI_SKU_Input__c + '\n';
        }
        return descriptionText;
    }
}