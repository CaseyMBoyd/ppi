/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 11.03.2024 <p/>
 * @test XaCalloutController_TEST
 *
 */

public without sharing class XaCalloutController {

    public static final String DELIVERY_METHOD_THIRD_PARTY = '3rd Party Bill To Address';

    @AuraEnabled
    public static List<ExternalService.XaApiService_getItemInventoryByItemNumber_OUT_200> fetchInventory(Id productId) {

        String productCode = [
            SELECT Id,
                ProductCode
            FROM Product2
            WHERE Id = :productId
            WITH SYSTEM_MODE
        ]?.ProductCode;

        ExternalService.XaApiService service = new ExternalService.XaApiService();

        ExternalService.XaApiService.getItemInventoryByItemNumber_Request request =
            new ExternalService.XaApiService.getItemInventoryByItemNumber_Request();

        request.itemNumber = productCode;

        ExternalService.XaApiService.getItemInventoryByItemNumber_Response response =
            service.getItemInventoryByItemNumber(request);

        return response.Code200;
    }

    @AuraEnabled
    public static Boolean canFulfillOrder(Id checkoutId, ExternalService.XaApiService_Address shippingAddress) {

        Id cartId = [
            SELECT WebCartId
            FROM CartCheckoutSession
            WHERE Id = :checkoutId
            WITH SYSTEM_MODE
        ].WebCartId;

        List<CartItem> items = [
            SELECT Id,
                Product2.ProductCode,
                Quantity
            FROM CartItem
            WHERE CartId = :cartId
            AND Type = 'Product'
            WITH SYSTEM_MODE
        ];

        if (items.size() > 1 || items.get(0).Quantity > 1) {
            List<ExternalService.XaApiService_postAvailableToAssemble_IN_body_items> requestItems =
                    new List<ExternalService.XaApiService_postAvailableToAssemble_IN_body_items>();

            for (CartItem cartItem : items) {
                ExternalService.XaApiService_postAvailableToAssemble_IN_body_items requestItem =
                        new ExternalService.XaApiService_postAvailableToAssemble_IN_body_items();

                requestItem.itemNumber = cartItem.Product2.ProductCode;
                requestItem.quantity = cartItem.Quantity.intValue();

                requestItems.add(requestItem);
            }


            ExternalService.XaApiService service = new ExternalService.XaApiService();

            ExternalService.XaApiService.postAvailableToAssemble_Request request =
                    new ExternalService.XaApiService.postAvailableToAssemble_Request();

            request.body = new ExternalService.XaApiService_postAvailableToAssemble_IN_body();
            request.body.items = requestItems;
            request.body.shippingAddress = shippingAddress;

            ExternalService.XaApiService.postAvailableToAssemble_Response response =
                    service.postAvailableToAssemble(request);

            return response.Code200?.canFulfill ?? false; // todo: how do we want to handle errors?
        } else {
            return true;
        }
    }

    @AuraEnabled
    public static String createContact(Contact contact) {

        ExternalService.XaApiService service = new ExternalService.XaApiService();
        ExternalService.XaApiService.putContactByCustomerNumberAndEmail_Request req =
            new ExternalService.XaApiService.putContactByCustomerNumberAndEmail_Request();

        req.customerNumber = createCustomerNumberFromAccount(contact.Account);
        req.email = contact.Email;
        req.body = new ExternalService.XaApiService_putContactByCustomerNumberAndEmail_IN_body();
        req.body.name = contact.Name;

        ExternalService.XaApiService.putContactByCustomerNumberAndEmail_Response res =
            service.putContactByCustomerNumberAndEmail(req);

        return res.Code201;
    }

    @AuraEnabled
    public static String fetchInvoice(Id orderSummaryId) {

        Order order = [
            SELECT OriginalOrder.External_Id__c
            FROM OrderSummary
            WHERE Id = :orderSummaryId
            WITH SYSTEM_MODE
        ]?.OriginalOrder;

        ExternalService.XaApiService service = new ExternalService.XaApiService();

        ExternalService.XaApiService.getOrderSalesforceInvoiceByExternalID_Request req =
            new ExternalService.XaApiService.getOrderSalesforceInvoiceByExternalID_Request();

        req.externalID = String.valueOf(order.External_Id__c);

        ExternalService.XaApiService.getOrderSalesforceInvoiceByExternalID_Response res =
            service.getOrderSalesforceInvoiceByExternalID(req);

        return res.Code200.invoicePDF;
    }

    @AuraEnabled
    public static ExternalService.XaApiService.putOrder_Response createOrder(Order order) {

        ExternalService.XaApiService service = new ExternalService.XaApiService();
        ExternalService.XaApiService.putOrder_Request req = prepareOrderRequest(order);

        Logger.info('Sending order to XA: ' + JSON.serialize(req))
            .setRecord(order.Id);
        
        ExternalService.XaApiService.putOrder_Response res = new ExternalService.XaApiService.putOrder_Response();

        try {
            res = service.putOrder(req);
            Logger.info('Received response from XA: ' + JSON.serialize(res))
            .setRecord(order.Id);
        } catch (Exception e) {
            Logger.error('Error sending order to XA: ' + e.getMessage())
                .setRecord(order.Id);
        }

        Logger.saveLog();

        return res;
    }

    public static String createCustomerNumberFromAccount(Account account) {
        if (account?.externalId__c == null && account?.Parent?.externalId__c == null) {
            throw new XaCalloutException('Account must have external id populated for this call');
        }

        String externalId = '' + (account.externalId__c ?? account?.Parent?.externalId__c);

        return externalId.left(externalId.length() - 2) + '-' + externalId.right(2);
    }

    public static Order fetchOrder(Id orderId) {
        return fetchOrders(new Set<Id>{orderId})[0];
    }

    public static List<Order> fetchOrders(Set<Id> orderIds) {
        return [
            SELECT Id,
                Account.externalId__c,
                Account.Parent.externalId__c,
                Account.companyNumber__c,
                // ADDED 06_10_26 by Ian Moore: Fetch Indirect Customer Code from Account
                Account.Indirect_Customer_No__c,
                CreatedBy.Name,
                CreatedBy.Email,
                PoNumber,
                OrderedDate,
                Owner.Name,
                External_Id__c,
                Integrated__c,
                BillingStreet,
                BillingCity,
                BillingStateCode,
                BillingPostalCode,
                Third_Party_Billing_Street1__c,
                Third_Party_Billing_Street2__c,
                Third_Party_Billing_City__c,
                Third_Party_Billing_Company__c,
                Third_Party_Billing_StateCode__c,
                Third_Party_Billing_Postal_Code__c,
                Allow_Split_Shipment__c,
                /* NEW: carrier fields on Order */
                Carrier__c,
                Carrier_Account_Number__c,
                Logistics_Information__c, (
                SELECT Id,
                    LineNumber,
                    Notes__c,
                    Product2.ProductCode,
                    Quantity,
                    UnitPrice
                FROM OrderItems
                WHERE Type = 'Order Product'
            ), (
                SELECT Id,
                    OrderDeliveryMethod.Name,
                    DeliverToName,
                    DeliveryInstructions,
                    DeliverToCompanyName,
                    DeliverToFullFirstName,
                    DeliverToFullLastName,
                    DeliverToStreet,
                    DeliverToCity,
                    DeliverToStateCode,
                    DeliverToPostalCode,
                    Ship_Date__c,
                    Company__c,
                    Ship_Option__c
                FROM OrderDeliveryGroups
            ), (
                SELECT Id,
                    ContentDocument.LatestPublishedVersion.VersionData,
                    ContentDocument.LatestPublishedVersion.Title,
                    ContentDocument.LatestPublishedVersion.FileType,
                    ContentDocument.LatestPublishedVersion.FileExtension
                FROM ContentDocumentLinks
                LIMIT 1
            )
            FROM Order
            WHERE Id IN :orderIds
            WITH SYSTEM_MODE
        ];
    }

    private static ExternalService.XaApiService.putOrder_Request prepareOrderRequest(Order order) {
        ExternalService.XaApiService.putOrder_Request req = new ExternalService.XaApiService.putOrder_Request();
        req.body = new ExternalService.XaApiService_Order();

        req.body.customerNumber = createCustomerNumberFromAccount(order.Account);
        // ADDED 06_10_26 by Ian Moore: Set indirectCustomerID from Account's Indirect Customer Code Field,
        // sent immediately after customerNumber to match required XA message structure for Indirect Customers.
        if (order.Account.Indirect_Customer_No__c != null) {
            req.body.indirectCustomerID = Integer.valueOf(order.Account.Indirect_Customer_No__c);
        }
        req.body.orderTime = order.OrderedDate;

        req.body.createdBy = new ExternalService.XaApiService_Order_createdBy();
        req.body.createdBy.name = order.CreatedBy.Name;
        req.body.createdBy.email = order.CreatedBy.Email;

        req.body.z0currency = 'USD';
        req.body.referenceOrder = order.Id;

        req.body.purchaseOrder = new ExternalService.XaApiService_Order_purchaseOrder();
        req.body.purchaseOrder.z0number = order.PoNumber;

        if(hasPoDocumentAttached(order)) {
            ContentVersion poDocument = order.ContentDocumentLinks[0].ContentDocument.LatestPublishedVersion;

            req.body.purchaseOrder.document = EncodingUtil.base64Encode(poDocument.VersionData);
            req.body.purchaseOrder.documentType = poDocument.FileExtension;
        }

        req.body.lineItems = new List<ExternalService.XaApiService_LineItem>();

        for (OrderItem item : order.OrderItems) {
            ExternalService.XaApiService_LineItem reqItem = new ExternalService.XaApiService_LineItem();

            reqItem.itemNumber = item.Product2.ProductCode;
            reqItem.quantity = item.Quantity.intValue();
            reqItem.unitPrice = item.UnitPrice;
            reqItem.lineNumber = item.LineNumber;
            reqItem.tag = item.Notes__c ?? 'N/A';

            req.body.lineItems.add(reqItem);
        }

        OrderDeliveryGroup deliveryGroup = order.OrderDeliveryGroups[0];

        req.body.shipping = new ExternalService.XaApiService_Order_shipping();
        req.body.shipping.delivery = deliveryGroup.Ship_Option__c ?? '';
        req.body.shipping.shipVia = deliveryGroup.OrderDeliveryMethod.Name;
        
        Date shipDate = deliveryGroup.Ship_Date__c ?? Date.today();
        req.body.shipping.requestedShipDate =
        DateTime.newInstance(shipDate, Time.newInstance(0, 0, 0, 0));  
        
        req.body.shipping.shippingAddress = new ExternalService.XaApiService_Address();
        req.body.shipping.shippingAddress.contact = deliveryGroup.Company__c;
        req.body.shipping.shippingAddress.city = deliveryGroup.DeliverToCity ?? '';
        req.body.shipping.shippingAddress.street1 = deliveryGroup.DeliverToStreet ?? '';
        req.body.shipping.shippingAddress.state = deliveryGroup.DeliverToStateCode ?? '';
        req.body.shipping.shippingAddress.zip = deliveryGroup.DeliverToPostalCode ?? '';
        String shippingInstructions = (order.Logistics_Information__c != null ? order.Logistics_Information__c + ' ' : '') + (deliveryGroup.DeliveryInstructions ?? '');
        req.body.shipping.shippingInstructions = shippingInstructions;
        req.body.shipping.carrier = order.Carrier__c ?? '';
        req.body.shipping.carrierAccountNumber = order.Carrier_Account_Number__c ?? '';

        if (DELIVERY_METHOD_THIRD_PARTY.equalsIgnoreCase(deliveryGroup.OrderDeliveryMethod.Name)) {
            req.body.shipping.freightBillingAddress = new ExternalService.XaApiService_Address();

            req.body.shipping.freightBillingAddress.contact = order.Third_Party_Billing_Company__c ?? '';
            req.body.shipping.freightBillingAddress.city = order.Third_Party_Billing_City__c ?? '';
            req.body.shipping.freightBillingAddress.street1 = order.Third_Party_Billing_Street1__c ?? '';
            req.body.shipping.freightBillingAddress.street2 = order.Third_Party_Billing_Street2__c ?? '';
            req.body.shipping.freightBillingAddress.state = order.Third_Party_Billing_StateCode__c ?? '';
            req.body.shipping.freightBillingAddress.zip = order.Third_Party_Billing_Postal_Code__c ?? '';
        }

        req.body.allowSplitShipments = order.Allow_Split_Shipment__c;

        return req;
    }

    
    public static BulkItemPricingResponse fetchBulkItemPricingByCustomerNumber(String customerNumber, Decimal indirectCustomerId, List<String> productCodes) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        String endpointString = 'callout:XA_API/item/pricing/'+customerNumber;
        if(indirectCustomerId != null) {
            endpointString += '?indirectCustomerID='+indirectCustomerId.round(System.RoundingMode.FLOOR);
        }
        req.setEndpoint(endpointString);
        req.setMethod('POST');
        List<Map<String,String>> postBody = new List<Map<String,String>>();
        for(String productCode : productCodes) {
            Map<String,String> codeMap = new Map<String,String>();
            codeMap.put('itemNumber', productCode);
            postBody.add(codeMap);
        }
        req.setBody(JSON.serialize(postBody));
        HttpResponse res = h.send(req);
        return (BulkItemPricingResponse) JSON.deserialize(res.getBody(), BulkItemPricingResponse.class);
    }

    private static Boolean hasPoDocumentAttached(Order order) {
        return !order.ContentDocumentLinks.isEmpty();
    }

    public class XaCalloutException extends Exception {
    }

    public class BulkItemPricingResponse {
        public String[] errors;
        public BulkItemPricing[] items;
    }

    public class BulkItemPricing {
        public String itemNumber;
        public Double listPrice;
        public Double sellPrice;
    }
}