@IsTest
private class ExternalManagedAccountControllerTest {
    @IsTest
    static void getCurrentExternalAccountName_success() {
        b2btd.xAccount testAccount = new b2btd.xAccount();
        testAccount.persist();
        b2btd.xContact testContact = new b2btd.xContact();
        testContact.withAccount(testAccount);
        testContact.persist();
        b2btd.xUser testUser = new b2btd.xUser();
        testUser.buyer(testContact);
        testUser.persist();

        b2btd.xAccount externalAccount = new b2btd.xAccount();
        externalAccount.set(Account.externalId__c, 43532.00);
        externalAccount.set(Account.companyNumber__c, 5);
        externalAccount.persist();

        Account expectedAccount = (Account) externalAccount.getRecord();
        User expectedUser = (User) testUser.getRecord();
        DelegatedAccount da = new DelegatedAccount();
        da.TargetId = expectedAccount.Id;
        da.Name = 'Test Account';
        da.ManagedById = expectedUser.Id;
        insert da;

        Test.startTest();
        String actualAccountName = ExternalManagedAccountController.getCurrentExternalAccountName(expectedAccount.Id);
        Assert.areEqual('Test Account', actualAccountName);
        Test.stopTest();
    }

    @IsTest
    static void getCurrentExternalAccountName_fail() {
        b2btd.xAccount testAccount = new b2btd.xAccount();
        testAccount.persist();
        b2btd.xContact testContact = new b2btd.xContact();
        testContact.withAccount(testAccount);
        testContact.persist();
        b2btd.xUser testUser = new b2btd.xUser();
        testUser.buyer(testContact);
        testUser.persist();

        b2btd.xAccount externalAccount = new b2btd.xAccount();
        externalAccount.set(Account.externalId__c, 43532.00);
        externalAccount.set(Account.companyNumber__c, 5);
        externalAccount.persist();

        Account expectedAccount = (Account) externalAccount.getRecord();
        User expectedUser = (User) testUser.getRecord();

        Test.startTest();
        try {
            String actualAccountName = ExternalManagedAccountController.getCurrentExternalAccountName(expectedAccount.Id);
        } catch (Exception e) {
            Assert.isNotNull(e);
        }
        Test.stopTest();
    }
}