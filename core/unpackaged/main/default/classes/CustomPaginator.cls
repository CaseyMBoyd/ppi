/**
 * Copyright (c) 2021 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author mkieczkowski/Forefront
 * @version 1.0
 * @description
 *
 * PURPOSE
 *
 *    DESC
 *
 * TEST CLASS
 *
 *    CustomPaginator_TEST
 *
 * CHANGE LOG
 *
 *    [Version; Date; Author; Description]
 *    v1.0; 27.04.2021; mkieczkowski/Forefront; Initial Build
 *
 **/

global abstract inherited sharing class CustomPaginator {
    public static PaginationResult paginateRecords(
            PaginationSettings settings,
            List<SObject> records
    ) {
        return new PassThroughPaginator(settings).paginate(records);
    }

    private class PassThroughPaginator extends CustomPaginator {
        public PassThroughPaginator(PaginationSettings settings) {
            super(settings);
        }

        public override Query getQuery() {
            return null;
        }
    }

    protected PaginationSettings settings;

    public CustomPaginator(PaginationSettings settings) {
        this.settings = settings;
    }

    global abstract Query getQuery();

    protected virtual List<SObject> sliceFoundRecords(List<SObject> records) {
        return CollectionUtils.splice(
                this.settings.currentRecordIndex,
                this.settings.pageSize,
                records
        );
    }

    protected virtual Object processBeforeReturn(List<SObject> records) {
        return records;
    }

    public PaginationResult paginate() {
        List<SObject> foundRecords = getQuery().toSObjectList();
        return paginate(foundRecords);
    }


    public PaginationResult paginate(List<SObject> records) {
        settings.totalRecords = records.size();
        settings.currentPage = Optional.of(settings.currentPage, 1);
        settings.totalPages = Math.ceil(
                Decimal.valueOf(settings.totalRecords) /
                        Decimal.valueOf(settings.pageSize)
        ).intValue();

        settings.lastPage = settings.totalPages;

        List<SObject> sliced = sliceFoundRecords(records);
        return new PaginationResult(settings, processBeforeReturn(sliced));
    }

    global class PaginationResult {
        @AuraEnabled
        public PaginationSettings settings { get; set; }
        @AuraEnabled
        public Object records { get; set; }

        public PaginationResult(PaginationSettings settings, Object records) {
            this.settings = settings;
            this.records = records;
        }

        @TestVisible
        private PaginationResult() {
        }
    }

    global class PaginationSettings {
        @AuraEnabled
        public Integer firstPage { get; set; }
        @AuraEnabled
        public Integer lastPage { get; set; }
        @AuraEnabled
        public Integer totalRecords { get; set; }
        @AuraEnabled
        public Integer totalPages { get; set; }
        @AuraEnabled
        public Integer currentPage { get; set; }
        @AuraEnabled
        public Integer pageSize { get; set; }

        public Integer currentRecordIndex {
            get {
                return (currentPage - 1) * pageSize;
            }
        }

        public PaginationSettings() {
            this.currentPage = 1;
            this.firstPage = 1;
            this.pageSize = 20;
        }
    }
}