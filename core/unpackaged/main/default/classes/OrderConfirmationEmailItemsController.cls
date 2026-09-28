/**
	* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author snguyen/Forefront
	* @version 1.0
	* @description
	*
	* PURPOSE
	* 
	*   Controller for OrderConfirmationEmailItemsController
	* 
	* TEST CLASS 
	* 
	*   OrderConfirmationEmailItemsController_TEST
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 3/19/2024; snguyen/Forefront; Initial Build
	* 
**/
public with sharing class OrderConfirmationEmailItemsController {

    public class EmailOrderItem {
        public String Name { get; set; }
        public String ImageUrl { get; set; }
        public String StockKeepingUnit { get; set; }
        public Decimal Quantity { get; set; }
        public Decimal Weight { get; set; }
        public String Total { get; set; }
    }

    public Id orderSummaryId { get; set; }
    public String communityName { get; set; }

    public List<EmailOrderItem> getEmailOrderItemList() {
        List<EmailOrderItem> emailOrderItemList = new List<EmailOrderItem>();

        if (String.isNotBlank(orderSummaryId)) {
            //Grab order item summaries to fetch product images
            List<OrderItemSummary> orderItemSummaries = getOrderItemSummaries(orderSummaryId);

            for (OrderItemSummary item : orderItemSummaries) {
                EmailOrderItem emailOrderItem = new EmailOrderItem();
                emailOrderItem.Name = item.Product2.Name;
                emailOrderItem.StockKeepingUnit = item.StockKeepingUnit;
                emailOrderItem.Quantity = item.Quantity;
                emailOrderItem.Weight = item.Product2.Weight__c;
                emailOrderItem.Total = String.valueOf(item.UnitPrice);

                emailOrderItemList.add(emailOrderItem);
            }
        }

        return emailOrderItemList;
    }

    private static List<OrderItemSummary> getOrderItemSummaries(String orderSummaryId) {
        return [
                SELECT
                        Id,
                        Name,
                        Quantity,
                        UnitPrice,
                        Product2Id,
                        TotalAdjustedLineTaxAmount,
                        TotalAdjustmentAmount,
                        TotalAdjustmentAmtWithTax,
                        TotalAdjustmentDistAmount,
                        TotalAdjustmentDistAmtWithTax,
                        TotalAdjustmentDistTaxAmount,
                        TotalAdjustmentTaxAmount,
                        TotalAmtWithTax,
                        TotalLineAdjustmentAmount,
                        TotalLineAdjustmentAmtWithTax,
                        TotalLineAdjustmentTaxAmount,
                        TotalLineAmount,
                        TotalLineAmountWithTax,
                        TotalLineTaxAmount,
                        TotalPrice,
                        TotalTaxAmount,
                        Type,
                        StockKeepingUnit,
                        Product2.Name,
                        Product2.Weight__c,
                        OriginalOrderItemId
                FROM OrderItemSummary
                WHERE Type != 'Delivery Charge' AND OrderSummaryId = :orderSummaryId
        ];
    }
}