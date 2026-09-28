/**
 * Copyright (c) 2021 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @version 1.0
 * @description
 *
 * PURPOSE
 *
 *    Test suite for CustomPaginator_TEST
 *
 * CHANGE LOG
 *
 *    [Version; Date; Author; Description]
 *    v1.0; 27.04.2021; pjendrzyca/Forefront; Initial Build
 *
 **/

@IsTest
private class CustomPaginator_TEST {
    @IsTest
    static void testPagination() {
        // given
        createAccounts(10);

        CustomPaginator.PaginationSettings pagination = new CustomPaginator.PaginationSettings();
        pagination.pageSize = 2;
        pagination.currentPage = 1;
        pagination.firstPage = 1;

        CustomPaginator paginator = new AwesomePaginator(pagination);

        // when
        CustomPaginator.PaginationResult results = paginator.paginate();

        // then
        CustomPaginator.PaginationSettings updatedPagination = results.settings;
        System.assertEquals(2, updatedPagination.pageSize);
        System.assertEquals(1, updatedPagination.currentPage);
        System.assertEquals(1, updatedPagination.firstPage);
        System.assertEquals(5, updatedPagination.totalPages);
        System.assertEquals(10, updatedPagination.totalRecords);

        List<Account> paginatedAccounts = (List<Account>) results.records;

        System.assertEquals(2, paginatedAccounts.size());

        // when
        updatedPagination.currentPage = 3;
        results = new AwesomePaginator(updatedPagination).paginate();

        // then
        updatedPagination = results.settings;
        System.assertEquals(2, updatedPagination.pageSize);
        System.assertEquals(3, updatedPagination.currentPage);
        System.assertEquals(1, updatedPagination.firstPage);
        System.assertEquals(5, updatedPagination.totalPages);
        System.assertEquals(10, updatedPagination.totalRecords);

        paginatedAccounts = (List<Account>) results.records;

        System.assertEquals(2, paginatedAccounts.size());
        System.assertEquals('4', paginatedAccounts[0].Name);
    }

    @IsTest
    static void testPaginateRecords() {
        // given
        List<Account> accounts = createAccounts(10);

        CustomPaginator.PaginationSettings settings = new CustomPaginator.PaginationSettings();
        settings.currentPage = 2;
        settings.pageSize = 5;

        // when
        CustomPaginator.PaginationResult paginationResult = CustomPaginator.paginateRecords(
                settings,
                accounts
        );

        // then
        Set<String> expectedAccountNames = new Set<String>{
                '5',
                '6',
                '7',
                '8',
                '9'
        };

        List<Account> currentPageRecords = (List<Account>) paginationResult.records;

        for (Account account : currentPageRecords) {
            System.assertEquals(
                    true,
                    expectedAccountNames.contains(account.Name)
            );
        }
    }

    private static List<Account> createAccounts(Integer count) {
        List<Account> accounts = new List<Account>();

        for (Integer i = 0; i < count; i++) {
            Account account = new Account();
            account.Name = String.valueOf(i);
            accounts.add(account);
        }

        insert accounts;
        return accounts;
    }

    private class AwesomePaginator extends CustomPaginator {
        public AwesomePaginator(PaginationSettings pagination) {
            super(pagination);
        }

        public override Query getQuery() {
            return new Query(Account.SObjectType).selectField(Account.Name);
        }
    }
}