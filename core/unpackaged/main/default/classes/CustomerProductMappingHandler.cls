/**
 * @description Trigger handler for Customer_Product_Mapping__c.
 * Pattern: Trigger -> Handler -> Queueable (asynchronous SKU validation).
 * - before insert: stamp Pending status, deactivate, build composite key,
 *                  block duplicates with a friendly message
 * - before update: rebuild composite key when the Customer Part Number changes,
 *                  block duplicates with a friendly message
 * - after insert:  enqueue async SKU validation
 * - after update:  re-enqueue only when the SKU input changed
 */
public with sharing class CustomerProductMappingHandler {

    // Prevents the Queueable's own status update from re-triggering validation
    // (which would loop forever on records that stay Invalid).
    @TestVisible
    public static Boolean bypassRevalidation = false;

    // Friendly message shown for a duplicate Customer Part Number on the account.
    // Enforced here (before-trigger) so EVERY DML path surfaces it: portal LWC,
    // native record modal, Data Loader, and cross-account copy. The Unique field
    // on Mapping_Composite_Key__c remains a backstop for concurrent inserts.
    @TestVisible
    private static final String DUPLICATE_MESSAGE =
        'This Customer Part Number is already mapped on this account.';

    public void run(
        List<Customer_Product_Mapping__c> newRecords,
        List<Customer_Product_Mapping__c> oldRecords,
        System.TriggerOperation operation
    ) {
        if (operation == System.TriggerOperation.BEFORE_INSERT) {
            normalizeToUpperCase(newRecords);
            setPendingStatus(newRecords);
            blockDuplicates(newRecords);
        } else if (operation == System.TriggerOperation.BEFORE_UPDATE) {
            normalizeToUpperCase(newRecords);
            restampCompositeKey(newRecords, oldRecords);
            blockDuplicates(newRecords);
        } else if (operation == System.TriggerOperation.AFTER_INSERT) {
            enqueueValidation(newRecords);
        } else if (operation == System.TriggerOperation.AFTER_UPDATE) {
            if (bypassRevalidation) {
                return;
            }
            List<Customer_Product_Mapping__c> toRevalidate =
                getRecordsToRevalidate(newRecords, oldRecords);
            if (!toRevalidate.isEmpty()) {
                enqueueValidation(toRevalidate);
            }
        }
    }

    // Normalize user-entered values to upper case so that the SKU input and
    // customer part number are stored consistently, regardless of how they were
    // typed (portal, admin, CSV upload, or cross-account copy). Runs in the
    // before-trigger context so the composite key and downstream comparisons all
    // use the normalized value. SOQL validation is case-insensitive, so this does
    // not change which product a SKU resolves to; it only standardizes storage.
    private void normalizeToUpperCase(List<Customer_Product_Mapping__c> records) {
        for (Customer_Product_Mapping__c record : records) {
            if (record.PPI_SKU_Input__c != null) {
                record.PPI_SKU_Input__c = record.PPI_SKU_Input__c.toUpperCase();
            }
            if (record.Customer_Part_Number__c != null) {
                record.Customer_Part_Number__c =
                    record.Customer_Part_Number__c.toUpperCase();
            }
        }
    }

    // Stamp initial state before the record is committed.
    private void setPendingStatus(List<Customer_Product_Mapping__c> records) {
        for (Customer_Product_Mapping__c record : records) {
            record.Validation_Status__c = 'Pending';
            record.Is_Active__c = false;
            if (record.Account__c != null && record.Customer_Part_Number__c != null) {
                record.Mapping_Composite_Key__c =
                    String.valueOf(record.Account__c) + '_' + record.Customer_Part_Number__c;
            }
        }
    }

    // Keep the composite key in sync when the Customer Part Number changes.
    private void restampCompositeKey(
        List<Customer_Product_Mapping__c> newRecords,
        List<Customer_Product_Mapping__c> oldRecords
    ) {
        Map<Id, Customer_Product_Mapping__c> oldMap =
            new Map<Id, Customer_Product_Mapping__c>(oldRecords);
        for (Customer_Product_Mapping__c rec : newRecords) {
            Customer_Product_Mapping__c old = oldMap.get(rec.Id);
            Boolean keyDriverChanged = old != null &&
                (rec.Customer_Part_Number__c != old.Customer_Part_Number__c
                 || rec.Account__c != old.Account__c);
            if (keyDriverChanged && rec.Account__c != null
                    && rec.Customer_Part_Number__c != null) {
                rec.Mapping_Composite_Key__c =
                    String.valueOf(rec.Account__c) + '_' + rec.Customer_Part_Number__c;
            }
        }
    }

    // Block a duplicate Customer Part Number per account with a clear message,
    // before the Unique field raises its raw system error. Catches both
    // collisions against existing records and duplicates within the same DML batch.
    private void blockDuplicates(List<Customer_Product_Mapping__c> records) {
        Set<String> keys = new Set<String>();
        for (Customer_Product_Mapping__c rec : records) {
            String key = buildKey(rec);
            if (key != null) {
                keys.add(key);
            }
        }
        if (keys.isEmpty()) {
            return;
        }

        // Existing records already using any of these keys (self excluded below).
        Map<String, Id> existingKeyToId = new Map<String, Id>();
        for (Customer_Product_Mapping__c existing : [
            SELECT Id, Mapping_Composite_Key__c
            FROM Customer_Product_Mapping__c
            WHERE Mapping_Composite_Key__c IN :keys
        ]) {
            existingKeyToId.put(existing.Mapping_Composite_Key__c, existing.Id);
        }

        Set<String> seenInBatch = new Set<String>();
        for (Customer_Product_Mapping__c rec : records) {
            String key = buildKey(rec);
            if (key == null) {
                continue;
            }
            Boolean dupInDb = existingKeyToId.containsKey(key)
                && existingKeyToId.get(key) != rec.Id; // exclude the record's own row on update
            if (dupInDb || seenInBatch.contains(key)) {
                rec.Customer_Part_Number__c.addError(DUPLICATE_MESSAGE);
            } else {
                seenInBatch.add(key);
            }
        }
    }

    // Composite key = AccountId + '_' + Customer Part Number (already upper-cased).
    // Mirrors the value stamped into Mapping_Composite_Key__c.
    private String buildKey(Customer_Product_Mapping__c rec) {
        if (rec.Account__c == null || String.isBlank(rec.Customer_Part_Number__c)) {
            return null;
        }
        return String.valueOf(rec.Account__c) + '_' + rec.Customer_Part_Number__c;
    }

    // Enqueue async validation for the given records.
    private void enqueueValidation(List<Customer_Product_Mapping__c> records) {
        List<Id> recordIds = new List<Id>();
        for (Customer_Product_Mapping__c r : records) {
            recordIds.add(r.Id);
        }
        if (!recordIds.isEmpty()) {
            System.enqueueJob(new CustomerProductMappingQueueable(recordIds));
        }
    }

    // Return records that need (re)validation. A record qualifies when:
    //  - the PPI SKU input changed, OR
    //  - the Customer Part Number changed, OR
    //  - the record is not yet successfully validated (Invalid or Pending).
    // A record already Valid whose SKU and part number are unchanged is skipped,
    // avoiding unnecessary async jobs.
    private List<Customer_Product_Mapping__c> getRecordsToRevalidate(
        List<Customer_Product_Mapping__c> newRecords,
        List<Customer_Product_Mapping__c> oldRecords
    ) {
        Map<Id, Customer_Product_Mapping__c> oldMap =
            new Map<Id, Customer_Product_Mapping__c>(oldRecords);
        List<Customer_Product_Mapping__c> toRevalidate =
            new List<Customer_Product_Mapping__c>();

        for (Customer_Product_Mapping__c rec : newRecords) {
            Customer_Product_Mapping__c old = oldMap.get(rec.Id);
            if (old == null) {
                continue;
            }

            Boolean skuChanged =
                rec.PPI_SKU_Input__c != old.PPI_SKU_Input__c;
            Boolean partNumberChanged =
                rec.Customer_Part_Number__c != old.Customer_Part_Number__c;
            Boolean notYetValid =
                rec.Validation_Status__c != 'Valid';

            if (skuChanged || partNumberChanged || notYetValid) {
                toRevalidate.add(rec);
            }
        }
        return toRevalidate;
    }
}