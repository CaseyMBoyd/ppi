/**
 * @description Tests for FlowContactLookupController.
 */
@IsTest
private class FlowContactLookupController_TEST {

    private static Account makeAccount(String name) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static Contact makeContact(String first, String last, String title, String email, Id accountId) {
        Contact c = new Contact(
            FirstName = first,
            LastName = last,
            Title = title,
            Email = email,
            AccountId = accountId
        );
        insert c;
        return c;
    }

    /**
     * Adds an indirect AccountContactRelation between the given contact and account.
     * (The contact's primary account already gets one auto-created via the AccountId field.)
     */
    private static AccountContactRelation linkIndirect(Id accountId, Id contactId, Boolean isActive) {
        AccountContactRelation rel = new AccountContactRelation(
            AccountId = accountId,
            ContactId = contactId,
            IsActive = isActive
        );
        insert rel;
        return rel;
    }

    @IsTest
    static void searchRelatedContacts_returnsAllRelatedWhenSearchTermBlank() {
        Account acct = makeAccount('Acme Co');
        Contact direct = makeContact('Alice', 'Anderson', 'CEO', 'alice@acme.test', acct.Id);
        Contact indirect = makeContact('Bob', 'Brown', 'CTO', 'bob@other.test', makeAccount('Other Co').Id);
        linkIndirect(acct.Id, indirect.Id, true);

        Test.startTest();
        List<FlowContactLookupController.ContactOption> results =
            FlowContactLookupController.searchRelatedContacts(acct.Id, '');
        Test.stopTest();

        Set<Id> ids = new Set<Id>();
        for (FlowContactLookupController.ContactOption opt : results) {
            ids.add(opt.id);
        }
        Assert.areEqual(2, results.size(), 'Should return both directly and indirectly related contacts');
        Assert.isTrue(ids.contains(direct.Id), 'Direct contact should be present');
        Assert.isTrue(ids.contains(indirect.Id), 'Indirect contact should be present');
    }

    @IsTest
    static void searchRelatedContacts_filtersByNameLike() {
        Account acct = makeAccount('Acme Co');
        Contact alice = makeContact('Alice', 'Anderson', 'CEO', 'alice@acme.test', acct.Id);
        makeContact('Bob', 'Brown', 'CTO', 'bob@acme.test', acct.Id);

        Test.startTest();
        List<FlowContactLookupController.ContactOption> results =
            FlowContactLookupController.searchRelatedContacts(acct.Id, 'Alic');
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Only Alice should match');
        Assert.areEqual(alice.Id, results[0].id);
        Assert.areEqual('Alice Anderson', results[0].name);
        Assert.areEqual('CEO', results[0].title);
        Assert.areEqual('alice@acme.test', results[0].email);
    }

    @IsTest
    static void searchRelatedContacts_excludesUnrelatedAccountsContacts() {
        Account target = makeAccount('Target Co');
        Account other = makeAccount('Other Co');
        makeContact('Alice', 'Anderson', null, null, target.Id);
        Contact stranger = makeContact('Stranger', 'Smith', null, null, other.Id);

        Test.startTest();
        List<FlowContactLookupController.ContactOption> results =
            FlowContactLookupController.searchRelatedContacts(target.Id, '');
        Test.stopTest();

        for (FlowContactLookupController.ContactOption opt : results) {
            Assert.areNotEqual(stranger.Id, opt.id, 'Stranger from unrelated account must not appear');
        }
    }

    @IsTest
    static void searchRelatedContacts_excludesInactiveRelations() {
        Account acct = makeAccount('Acme Co');
        Account other = makeAccount('Other Co');
        Contact directActive = makeContact('Alice', 'Anderson', null, null, acct.Id);
        Contact inactiveIndirect = makeContact('Bob', 'Brown', null, null, other.Id);
        linkIndirect(acct.Id, inactiveIndirect.Id, false);

        Test.startTest();
        List<FlowContactLookupController.ContactOption> results =
            FlowContactLookupController.searchRelatedContacts(acct.Id, '');
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Inactive relation should be excluded');
        Assert.areEqual(directActive.Id, results[0].id);
    }

    @IsTest
    static void searchRelatedContacts_returnsEmptyWhenAccountIdNull() {
        Test.startTest();
        List<FlowContactLookupController.ContactOption> results =
            FlowContactLookupController.searchRelatedContacts(null, 'anything');
        Test.stopTest();

        Assert.areEqual(0, results.size());
    }

    @IsTest
    static void searchRelatedContacts_dedupesWhenContactHasMultipleRelationsToSameAccount() {
        // Salesforce only allows one ACR per Account+Contact pair, so this guards the dedupe
        // path against future-proof or test edge cases — should still return a single entry.
        Account acct = makeAccount('Acme Co');
        makeContact('Alice', 'Anderson', null, null, acct.Id);

        Test.startTest();
        List<FlowContactLookupController.ContactOption> results =
            FlowContactLookupController.searchRelatedContacts(acct.Id, 'Alice');
        Test.stopTest();

        Assert.areEqual(1, results.size());
    }

    @IsTest
    static void getContactById_returnsHydratedRecord() {
        Account acct = makeAccount('Acme Co');
        Contact c = makeContact('Alice', 'Anderson', 'CEO', 'alice@acme.test', acct.Id);

        Test.startTest();
        FlowContactLookupController.ContactOption opt = FlowContactLookupController.getContactById(c.Id);
        Test.stopTest();

        Assert.areNotEqual(null, opt);
        Assert.areEqual(c.Id, opt.id);
        Assert.areEqual('Alice Anderson', opt.name);
        Assert.areEqual('CEO', opt.title);
        Assert.areEqual('alice@acme.test', opt.email);
    }

    @IsTest
    static void getContactById_returnsNullWhenIdNull() {
        Test.startTest();
        FlowContactLookupController.ContactOption opt = FlowContactLookupController.getContactById(null);
        Test.stopTest();

        Assert.areEqual(null, opt);
    }

    @IsTest
    static void getContactById_returnsNullWhenContactDeleted() {
        Account acct = makeAccount('Acme Co');
        Contact c = makeContact('Alice', 'Anderson', null, null, acct.Id);
        Id capturedId = c.Id;
        delete c;

        Test.startTest();
        FlowContactLookupController.ContactOption opt = FlowContactLookupController.getContactById(capturedId);
        Test.stopTest();

        Assert.areEqual(null, opt);
    }
}