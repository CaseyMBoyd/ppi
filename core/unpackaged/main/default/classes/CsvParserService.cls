/**
 * @description Parses the Customer Part Number upload CSV (comma-delimited).
 * Required headers: Customer_Part_Number, PPI_Part_Number (case-insensitive).
 * Returns Customer_Product_Mapping__c records ready for upsert by composite key.
 * SKU validation itself is asynchronous (trigger -> queueable); the parser only
 * shapes records and never rejects rows for SKU content.
 */
public with sharing class CsvParserService {

    @TestVisible private static final String HEADER_CUSTOMER_PN = 'Customer_Part_Number';
    @TestVisible private static final String HEADER_PPI_SKU = 'PPI_Part_Number';

    public static List<Customer_Product_Mapping__c> parse(
        String csvContent, Id accountId
    ) {
        List<Customer_Product_Mapping__c> records =
            new List<Customer_Product_Mapping__c>();

        if (String.isBlank(csvContent) || accountId == null) {
            return records;
        }

        List<String> lines = csvContent.split('\n');
        if (lines.isEmpty()) {
            return records;
        }

        List<String> headers = lines[0].replace('\r', '').split(',');
        Integer customerPnIndex = getHeaderIndex(headers, HEADER_CUSTOMER_PN);
        Integer ppiSkuIndex = getHeaderIndex(headers, HEADER_PPI_SKU);

        if (customerPnIndex == -1 || ppiSkuIndex == -1) {
            throw new AuraHandledException(
                'Invalid CSV format. Required columns: '
                + HEADER_CUSTOMER_PN + ', ' + HEADER_PPI_SKU
            );
        }

        for (Integer i = 1; i < lines.size(); i++) {
            String line = lines[i].replace('\r', '').trim();
            if (String.isBlank(line)) {
                continue;
            }

            List<String> cols = line.split(',');
            if (cols.size() <= Math.max(customerPnIndex, ppiSkuIndex)) {
                continue;
            }

            String customerPn = cols[customerPnIndex].trim();
            String ppiSku = cols[ppiSkuIndex].trim();
            if (String.isBlank(customerPn) || String.isBlank(ppiSku)) {
                continue;
            }

            records.add(new Customer_Product_Mapping__c(
                Account__c = accountId,
                Customer_Part_Number__c = customerPn,
                PPI_SKU_Input__c = ppiSku,
                Source_Type__c = 'Portal',
                Mapping_Composite_Key__c =
                    String.valueOf(accountId) + '_' + customerPn
            ));
        }
        return records;
    }

    private static Integer getHeaderIndex(List<String> headers, String target) {
        for (Integer i = 0; i < headers.size(); i++) {
            if (headers[i].trim().equalsIgnoreCase(target)) {
                return i;
            }
        }
        return -1;
    }
}