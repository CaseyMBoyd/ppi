/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author jakub_cichacki/Forefront
 * @date 17.06.2024
 * @test 
 **/
public without sharing class OrderController {

    public static final Commerce_Setting__mdt COMMERCE_SETTING = Commerce_Setting__mdt.getInstance('PPI_Commerce');
    public static final String ORDER_ITEM_SUMMARY_DELIVERY_CHARGE_TYPE = 'Delivery Charge';

    @AuraEnabled
    public static List<OrderSummary> getOrderSummaries(Map<String, String> filters, Integer pageSize, String sortBy, String sortDirection) {
        Set<Id> accountsIds = new Set<Id>();

        if(filters.containsKey('effectiveAccountId') && filters.get('effectiveAccountId') != null) {
            accountsIds.add(filters.get('effectiveAccountId'));
        } else {
            accountsIds.add(BuyerService.effectiveAccountId);
        }

        List<DelegatedAccount> delegatedAccounts = [SELECT TargetId FROM DelegatedAccount WHERE ManagedById = :UserInfo.getUserId()];
        accountsIds.addAll(Stream.of(delegatedAccounts).toSetOfIds(DelegatedAccount.TargetId));

        List<Account> accounts = [SELECT Id, ParentId FROM Account WHERE Id IN :accountsIds OR ParentId IN :accountsIds LIMIT 1];

        for (Account acc : accounts) {
            if (account.ParentId != null) {
                accountsIds.add(acc.ParentId);
            }

            accountsIds.add(acc.Id);
        }

        accountsIds.remove(null);

        List<SObjectField> fields = new List<SObjectField>{
            OrderSummary.PoNumber,
            OrderSummary.TotalAmount,
            OrderSummary.OrderNumber,
            OrderSummary.OrderedDate,
            OrderSummary.Ordered_Date_Only__c,
            OrderSummary.Order_Status__c,
            OrderSummary.PPI_Order_Number__c
        };

        Query orderSummaryQuery = new Query(OrderSummary.SObjectType)
                .selectFields(fields)
                .addSubquery(Query.subquery('OrderItemSummaries')
                        .selectFields('Id')
                        .addConditionNotEq('Type', ORDER_ITEM_SUMMARY_DELIVERY_CHARGE_TYPE)
                        .addCondition(Query.doOr(
                                Query.conditionEq('Product2.external_ID__c', COMMERCE_SETTING.Generic_Product_External_Id__c),
                                Query.conditionEq('Product2.IsActive', false)
                        ))
                )
                .addConditionIn('AccountId', accountsIds);

        filters.remove('effectiveAccountId');
        for (String key : filters.keySet()) {
            if (key == 'startDate' && filters.get(key) != null) {
                orderSummaryQuery.addConditionGe('OrderedDate', Datetime.valueOf(filters.get(key).split('T')[0] + ' 00:00:00'));
            } else if (key == 'endDate' && filters.get(key) != null) {
                orderSummaryQuery.addConditionLe('OrderedDate', Datetime.valueOf(filters.get(key).split('T')[0] + ' 23:59:59'));
            } else if (String.isNotBlank(filters.get(key))) {
                orderSummaryQuery.addConditionLike(key, '%' + filters.get(key) + '%');
            }
        }

        if (String.isNotBlank(sortBy)) {
            orderSummaryQuery.orderBy(sortBy, sortDirection);
        }

        orderSummaryQuery.setLimit(pageSize ?? 25);

        List<OrderSummary> orderSummaries = orderSummaryQuery.run();
        return orderSummaries;
    }

    @AuraEnabled(Cacheable=true)
    public static Boolean isReorderPossible(String orderSummaryId) {
        List<OrderItemSummary> orderItemSummaries = [
                SELECT Id
                FROM OrderItemSummary
                WHERE OrderSummaryId = :orderSummaryId
                    AND Type != :ORDER_ITEM_SUMMARY_DELIVERY_CHARGE_TYPE
                    AND (Product2.external_ID__c = :COMMERCE_SETTING.Generic_Product_External_Id__c
                        OR Product2.IsActive = FALSE)
                WITH SYSTEM_MODE
        ];
        return orderItemSummaries.isEmpty();
    }

    @AuraEnabled(Cacheable=true)
    public static List<OrderItemSummary> getOrderItemSummaries(String orderSummaryId, List<String> fields) {
        Set<String> fieldsSet = new Set<String>(fields);
        List<String> fieldsToAdd = new List<String>{'Id', 'Name', 'Padded_Line_Number__c', 'Product2Id'};
        for(String field : fieldsToAdd) {
            fieldsSet.add(field);
        }

        List<OrderItemSummary> orderItemSummaries = new Query(OrderItemSummary.SObjectType)
                .selectFields(fieldsSet)
                .addConditionEq('OrderSummaryId', orderSummaryId)
                .addConditionNotEq('Type', ORDER_ITEM_SUMMARY_DELIVERY_CHARGE_TYPE)
                .orderBy('LineNumber')
                .run();

        return orderItemSummaries;
    }

    @AuraEnabled(Cacheable=true)
    public static OrderDeliveryMethodWrapper getOrderDeliveryMethod(String orderSummaryId) {
        OrderDeliveryGroupSummary  orderDeliveryMethod = (OrderDeliveryGroupSummary ) new Query(OrderDeliveryGroupSummary.SObjectType)
                .selectFields('DeliverToName, DeliverToCity, DeliverToStreet, DeliverToState, DeliverToPostalCode, DeliverToCountry')
                .addConditionEq('OrderSummaryId', orderSummaryId)
                .fetch();

        OrderItemSummary deliveryCharge = (OrderItemSummary) new Query(OrderItemSummary.SObjectType)
                .selectFields('Name')
                .addConditionEq('OrderSummaryId', orderSummaryId)
                .addConditionEq('Type', ORDER_ITEM_SUMMARY_DELIVERY_CHARGE_TYPE)
                .fetch();

        return new OrderDeliveryMethodWrapper(orderDeliveryMethod, deliveryCharge?.Name);
    }

    public class OrderDeliveryMethodWrapper {
        @AuraEnabled
        public OrderDeliveryGroupSummary orderDeliveryGroup { get; set; }
        @AuraEnabled
        public String shippingMethodName { get; set; }

        public OrderDeliveryMethodWrapper(OrderDeliveryGroupSummary orderDeliveryGroupSummary, String shippingMethodName) {
            this.orderDeliveryGroup = orderDeliveryGroupSummary;
            this.shippingMethodName = shippingMethodName ?? '';
        }
    }
}