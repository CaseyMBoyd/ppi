/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 23/12/2024
 * @test CommerceRepriceOpenCartsBatch_TEST_TEST
 *
 */

@IsTest
private class CommerceRepriceOpenCartsBatch_TEST {

    @IsTest
    static void testBatch() {
        // given
        WebStore testWebStore = new WebStore(Name = 'Test Store');
        insert testWebStore;

        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        WebCart cartPrimary = new WebCart(
            Name = 'Cart Primary',
            Status = 'Active',
            AccountId = testAccount.Id,
            WebStoreId = testWebStore.Id
        );
        insert cartPrimary;

        WebCart cartSecondary = new WebCart(
            Name = 'Cart Secondary',
            Status = 'Active',
            IsSecondary = true,
            AccountId = testAccount.Id,
            WebStoreId = testWebStore.Id
        );
        insert cartSecondary;

        // when called without seeAllData true should fail to reprice
        Test.startTest();
        CommerceRepriceOpenCartsBatch batch = new CommerceRepriceOpenCartsBatch();
        Database.executeBatch(batch, 2);
        Test.stopTest();

        // then
        List<LogEntry__c> logs = [
            SELECT Message__c, LoggingLevel__c, RecordId__c, Tags__c
            FROM LogEntry__c
        ];
        Assert.isFalse(logs.isEmpty(), 'logs should be created.');

        Boolean hasError = false;

        for (LogEntry__c log : logs) {
            if (log.LoggingLevel__c == 'ERROR') {
                hasError = true;
                break;
            }
        }

        Assert.isTrue(hasError, 'Error log should be created.');
    }
}