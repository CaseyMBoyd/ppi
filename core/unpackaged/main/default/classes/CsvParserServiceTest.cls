/**
 * @description Tests for CsvParserService.
 */
@IsTest
private class CsvParserServiceTest {

    private static Id accountId() {
        Account acc = new Account(Name = 'CSV Test Account');
        insert acc;
        return acc.Id;
    }

    @IsTest
    static void parse_validCsv_returnsRecords() {
        Id accId = accountId();
        String csv = 'Customer_Part_Number,PPI_Part_Number\n'
            + 'CUST-A,SKU-1\n'
            + 'CUST-B,SKU-2\n';

        List<Customer_Product_Mapping__c> records =
            CsvParserService.parse(csv, accId);

        Assert.areEqual(2, records.size(), 'Two data rows expected');
        Assert.areEqual('CUST-A', records[0].Customer_Part_Number__c);
        Assert.areEqual('SKU-1', records[0].PPI_SKU_Input__c);
        Assert.areEqual('Portal', records[0].Source_Type__c);
        Assert.areEqual(String.valueOf(accId) + '_CUST-A',
            records[0].Mapping_Composite_Key__c);
    }

    @IsTest
    static void parse_crlfAndCaseInsensitiveHeaders_supported() {
        Id accId = accountId();
        String csv = 'customer_part_number,ppi_part_number\r\n'
            + 'CUST-C,SKU-3\r\n';

        List<Customer_Product_Mapping__c> records =
            CsvParserService.parse(csv, accId);

        Assert.areEqual(1, records.size(), 'CRLF row must parse');
        Assert.areEqual('SKU-3', records[0].PPI_SKU_Input__c,
            'CR must be stripped from values');
    }

    @IsTest
    static void parse_skipsBlankAndIncompleteLines() {
        Id accId = accountId();
        String csv = 'Customer_Part_Number,PPI_Part_Number\n'
            + '\n'
            + 'ONLY-ONE-COLUMN\n'
            + 'CUST-D,\n'
            + ',SKU-9\n'
            + 'CUST-E,SKU-5\n';

        List<Customer_Product_Mapping__c> records =
            CsvParserService.parse(csv, accId);

        Assert.areEqual(1, records.size(),
            'Blank, incomplete and half-empty rows must be skipped');
        Assert.areEqual('CUST-E', records[0].Customer_Part_Number__c);
    }

    @IsTest
    static void parse_missingHeaders_throws() {
        Id accId = accountId();
        String csv = 'Wrong_Header,Another\nA,B\n';

        try {
            CsvParserService.parse(csv, accId);
            Assert.fail('Missing required headers must throw');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'Expected exception thrown');
        }
    }

    @IsTest
    static void parse_blankContentOrNullAccount_returnsEmpty() {
        Assert.areEqual(0, CsvParserService.parse('', accountId()).size());
        Assert.areEqual(0, CsvParserService.parse('a,b\nc,d', null).size());
    }
}