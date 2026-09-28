@IsTest
private class InventoryLocationTransformer_TEST {

    @IsTest
    static void testGetFriendlyLocationNamesBulk() {

        Set<String> rawCodes = new Set<String>{
            'B',
            'M',
            'UNKNOWN'
        };

        Test.startTest();

        Map<String, String> results =
            InventoryLocationTransformer.getFriendlyLocationNamesBulk(rawCodes);

        Test.stopTest();

        System.assertNotEquals(
            null,
            results,
            'Result map should not be null.'
        );

        if (results.containsKey('B')) {
            System.assertNotEquals(
                null,
                results.get('B'),
                'Mapped code B should return a display name.'
            );
        }

        System.assertEquals(
            false,
            results.containsKey('UNKNOWN'),
            'Unknown ERP codes should not be included.'
        );
    }

    @IsTest
    static void testNullInput() {

        Test.startTest();

        Map<String, String> results =
            InventoryLocationTransformer.getFriendlyLocationNamesBulk(null);

        Test.stopTest();

        System.assertNotEquals(
            null,
            results,
            'Null input should return an empty map.'
        );

        System.assertEquals(
            0,
            results.size(),
            'Null input should return an empty map.'
        );
    }

    @IsTest
    static void testEmptyInput() {

        Test.startTest();

        Map<String, String> results =
            InventoryLocationTransformer.getFriendlyLocationNamesBulk(
                new Set<String>()
            );

        Test.stopTest();

        System.assertEquals(
            0,
            results.size(),
            'Empty input should return an empty map.'
        );
    }

    @IsTest
    static void testBlankCodes() {

        Set<String> rawCodes = new Set<String>{
            '',
            ' '
        };

        Test.startTest();

        Map<String, String> results =
            InventoryLocationTransformer.getFriendlyLocationNamesBulk(rawCodes);

        Test.stopTest();

        System.assertNotEquals(
            null,
            results,
            'Result should never be null.'
        );

        /*
         * Current implementation adds blank values as-is.
         */
        System.assert(
            results.containsKey(''),
            'Blank key should exist.'
        );

        System.assertEquals(
            '',
            results.get(''),
            'Blank values should pass through unchanged.'
        );
    }

    @IsTest
    static void testCacheInitialization() {

        Set<String> rawCodes = new Set<String>{ 'B' };

        Test.startTest();

        Map<String, String> firstCall =
            InventoryLocationTransformer.getFriendlyLocationNamesBulk(rawCodes);

        Map<String, String> secondCall =
            InventoryLocationTransformer.getFriendlyLocationNamesBulk(rawCodes);

        Test.stopTest();

        System.assertEquals(
            firstCall,
            secondCall,
            'Static cache should return consistent results.'
        );
    }
}