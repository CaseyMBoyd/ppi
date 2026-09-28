/**
 * Copyright (c) 2021 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author jclappsy/Forefront
 * @version 1.0
 * @description
 *
 * PURPOSE
 *
 *
 *
 * TEST CLASS
 *
 *
 *
 * ENTRY POINTS
 *
 *
 *
 * CHANGE LOG
 *
 *    [Version; Date; Author; Description]
 *    v1.0; 10/26/2021; jclappsy/Forefront; Initial Build
 *
 **/
@IsTest
public without sharing class b2btd {
    public class TestDataException extends Exception {
    }

    private static Integer fakeIdsCounter = 0;
    private static Integer nameIndex = 0;

    /**
     * Generates fake id for given SObject prefix
     *
     * @param prefix
     *
     * @return String
     */
    public static String generateFakeId(String prefix) {
        String numberString = String.valueOf(fakeIdsCounter++);
        return prefix + '0'.repeat(12 - numberString.length()) + numberString;
    }

    /**
     * Generates fake id for given SObjectType
     *
     * @param sType
     *
     * @return String
     */
    public static String generateFakeId(SObjectType sType) {
        String numberString = String.valueOf(fakeIdsCounter++);
        String prefix = sType.getDescribe().getKeyPrefix();
        return prefix + '0'.repeat(12 - numberString.length()) + numberString;
    }

    /**
     * Generates fake ids for a set of Sobjects
     *
     * @param records
     */
    public static void generateFakeId(List<SObject> records) {
        for (SObject record : records) {
            record.Id = record.Id != null ? record.Id : generateFakeId(record.getSObjectType());
        }
    }

    public static final Id STANDARD_USER {
        get {
            if (STANDARD_USER == null) {
                STANDARD_USER = [
                    SELECT Id
                    FROM Profile
                    WHERE Name = 'Standard User'
                ]
                .Id;
            }
            return STANDARD_USER;
        }
        private set;
    }

    public static final Id ADMIN_USER {
        get {
            if (ADMIN_USER == null) {
                ADMIN_USER = [
                    SELECT Id
                    FROM Profile
                    WHERE Name = 'System Administrator'
                ]
                .Id;
            }
            return ADMIN_USER;
        }
        private set;
    }

    public static final Id BUYER_USER {
        get {
            if (BUYER_USER == null) {
                BUYER_USER = [
                    SELECT Id
                    FROM Profile
                    WHERE Name = 'PPI Customer Portal User'
                ]
                .Id;
            }
            return BUYER_USER;
        }
        private set;
    }

    public static final Id BUYER_MANAGER_USER {
        get {
            if (BUYER_MANAGER_USER == null) {
                BUYER_MANAGER_USER = [
                    SELECT Id
                    FROM Profile
                    WHERE Name = 'Buyer Manager'
                ]
                .Id;
            }
            return BUYER_MANAGER_USER;
        }
        private set;
    }

    public static final Id ROLE_PORTAL {
        get {
            if (ROLE_PORTAL == null) {
                ROLE_PORTAL = [
                    SELECT Id
                    FROM UserRole
                    WHERE PortalType = 'None'
                    LIMIT 1
                ]
                .Id;
            }
            return ROLE_PORTAL;
        }
        private set;
    }

    public class xProduct extends DomainBuilder {
        public xProduct() {
            super(Product2.SObjectType);
            set(Product2.IsActive, true);
            set(Product2.sellable_erp__c, true);
            set(Product2.sellable_override__c, false);
            name('testProduct' + nameIndex++);
            sku('testSku' + nameIndex++);
        }

        public xProduct name(String v) {
            set(Product2.Name, v);
            return this;
        }

        public xProduct productCode(String v) {
            set(Product2.ProductCode, v);
            return this;
        }

        public xProduct sku(String v) {
            set(Product2.StockKeepingUnit, v);
            return this;
        }

        public xProduct image(String v) {
            set(Product2.DisplayUrl, v);
            return this;
        }
    }

    public class xUser extends DomainBuilder {
        public xUser() {
            super(User.SObjectType);

            String name = 'random_421_testUser' + nameIndex++;
            set(User.Alias, 'alias');
            set(User.Email, name + '@testforefront.com');
            set(User.EmailEncodingKey, 'UTF-8');
            set(User.FirstName, 'Jhon');
            set(User.Lastname, 'Test');
            set(User.languagelocalekey, 'en_US');
            set(User.localesidkey, 'en_US');
            set(User.timezonesidkey, 'America/Los_Angeles');
            set(User.isActive, true);
            set(User.username, name + '@testforefront.com');
            set(User.profileId, STANDARD_USER);
            set(User.UserPermissionsSFContentUser, false);
        }

        public xUser standard() {
            set(User.profileId, STANDARD_USER);
            return this;
        }

        public xUser adminWithRole() {
            set(User.profileId, ADMIN_USER);
            set(User.UserRoleId, ROLE_PORTAL);
            return this;
        }

        public xUser buyer(xContact contact) {
            set(User.profileId, BUYER_USER);
            set(User.username, 'customerCare@fftest.com' + nameIndex++);
            setParent(User.ContactId, contact);
            return this;
        }

        public xUser buyerManager(xContact contact) {
            set(User.profileId, BUYER_MANAGER_USER);
            set(User.username, 'communityUser@fftest.com' + nameIndex++);
            setParent(User.ContactId, contact);
            return this;
        }
    }

    public class xContact extends DomainBuilder {
        public xContact() {
            super(Contact.SObjectType);

            set(Contact.MailingCountryCode, 'US');

            first('Test');
            last('Contact' + nameIndex++);
        }

        public xContact first(String name) {
            set(Contact.FirstName, name);
            return this;
        }

        public xContact last(String name) {
            set(Contact.LastName, name);
            return this;
        }

        public xContact withAccount(xAccount account) {
            setParent(Contact.AccountId, account);
            return this;
        }
    }

    public class xOrder extends DomainBuilder {
        public List<OrderItem> lines { get; private set; }

        public xOrder() {
            super(Order.SObjectType);

            this.lines = new List<OrderItem>();

            setParent(Order.AccountId, new xAccount());
            set(Order.EffectiveDate, Date.today());
            set(Order.Status, 'Draft');

            set(Order.ShippingStreet, 'River Rd 800');
            set(Order.ShippingCity, 'Fair Haven');
            set(Order.ShippingStateCode, 'NJ');
            set(Order.ShippingPostalCode, '07704');
            set(Order.ShippingCountryCode, 'US');
        }

        public xOrder orderType(String v) {
            set(Order.Type, v);
            return this;
        }

        public xOrder orderedDate(Datetime v) {
            set(Order.OrderedDate, v);
            return this;
        }

        public xOrder withOrderItem() {
            OrderItem line = (OrderItem) new xOrderItem().withOrder(this).getRecord();

            this.lines.add(line);

            return this;
        }

        public xOrder account(Id accountID) {
            set(Order.AccountId, accountID);

            return this;
        }

        public xOrder account(xAccount account) {
            setParent(Order.AccountId, account);

            return this;
        }
    }

    public class xOrderItem extends DomainBuilder {
        public xOrderItem() {
            super(OrderItem.SObjectType);

            set(OrderItem.ListPrice, 100);
            set(OrderItem.UnitPrice, 100);
            set(OrderItem.TotalLineAmount, 100);
            set(OrderItem.Quantity, 1);
            set(OrderItem.ListPrice, 100);
            setParent(OrderItem.Product2Id, new xProduct());
        }

        public xOrderItem typeProduct() {
            set(OrderItem.Type, 'Order Product');
            return this;
        }

        public xOrderItem typeDeliveryCharge() {
            set(OrderItem.Type, 'Delivery Charge');
            return this;
        }

        public xOrderItem product(xProduct product) {
            setParent(OrderItem.Product2Id, product);
            return this;
        }

        public xOrderItem withOrder(Id v) {
            set(OrderItem.OrderId, v);
            return this;
        }

        public xOrderItem withOrder(xOrder order) {
            setParent(OrderItem.OrderId, order);
            return this;
        }

        public xOrderItem orderDeliveryGroup(Id v) {
            set(OrderItem.OrderDeliveryGroupId, v);
            return this;
        }
    }

    public class xOrderDeliveryMethod extends DomainBuilder {
        public xOrderDeliveryMethod() {
            super(OrderDeliveryMethod.SObjectType);

            set(OrderDeliveryMethod.Name, 'test_delivery_method' + nameIndex++);
        }
    }

    public class xOrderDeliveryGroup extends DomainBuilder {
        public xOrderDeliveryGroup() {
            super(OrderDeliveryGroup.SObjectType);

            set(OrderDeliveryGroup.Description, 'test_delivery_method' + nameIndex++);
            set(OrderDeliveryGroup.DesiredDeliveryDate, Date.today());
            set(OrderDeliveryGroup.DeliverToName, 'test');
            set(OrderDeliveryGroup.DeliveryInstructions, 'test');
            set(OrderDeliveryGroup.DeliverToStreet, 'River Rd 800');
            set(OrderDeliveryGroup.DeliverToStateCode, 'NY');
            set(OrderDeliveryGroup.DeliverToCity, 'Fair Haven');
            set(OrderDeliveryGroup.DeliverToPostalCode, '7250');
            set(OrderDeliveryGroup.DeliverToCountryCode, 'US');
            set(OrderDeliveryGroup.DeliverToCity, 'Fair Haven');

            setParent(OrderDeliveryGroup.OrderDeliveryMethodId, new xOrderDeliveryMethod());
        }

        public xOrderDeliveryGroup withOrder(Id v) {
            set(OrderDeliveryGroup.OrderId, v);
            return this;
        }

        public xOrderDeliveryGroup withOrder(xOrder order) {
            setParent(OrderDeliveryGroup.OrderId, order);
            return this;
        }
    }

    public class xAccount extends DomainBuilder {
        public xAccount() {
            super(Account.SObjectType);

            name('AccountTest' + nameIndex++);
            set(Account.externalId__c, 999999.00);
            set(Account.companyNumber__c, 10);
            withAddress();
        }

        public xAccount withAddress() {
            set(Account.Phone, '123-456-7890');
            set(Account.BillingStreet, '800 River Rd');
            set(Account.BillingCity, 'Fair Haven');
            set(Account.BillingCountryCode, 'US');
            set(Account.BillingStateCode, 'NJ');
            set(Account.BillingPostalCode, '07704');
            set(Account.ShippingStreet, '800 River Rd');
            set(Account.ShippingCity, 'Fair Haven');
            set(Account.ShippingCountryCode, 'US');
            set(Account.ShippingStateCode, 'NJ');
            set(Account.ShippingPostalCode, '07704');
            return this;
        }

        public xAccount name(String name) {
            set(Account.Name, name);
            return this;
        }

        public xAccount parent(Id v) {
            set(Account.ParentId, v);
            return this;
        }

        public xAccount ofType(String v) {
            set(Account.Type, v);
            return this;
        }

        public xAccount owner(Id ownerId) {
            set(Account.OwnerId, ownerId);
            return this;
        }

        public xAccount makeBuyerAccount() {
            new xBuyerAccount(this);
            return this;
        }
    }

    public class xBuyerGroup extends DomainBuilder {
        public xBuyerGroup() {
            super(BuyerGroup.SObjectType);

            name('BuyerGroupTest');
        }

        public xBuyerGroup name(String name) {
            set(BuyerGroup.Name, name);
            return this;
        }
    }

    public class xBuyerGroupMember extends DomainBuilder {
        public xBuyerGroupMember(xAccount account, xBuyerGroup buyerGroup) {
            super(BuyerGroupMember.SObjectType);
            setParent(BuyerGroupMember.BuyerId, account);
            setParent(BuyerGroupMember.BuyerGroupId, buyerGroup);
        }
    }

    public class xWebstore extends DomainBuilder {
        public xWebstore() {
            super(WebStore.SObjectType);

            name('WebstoreTest');
        }

        public xWebstore name(String name) {
            set(WebStore.Name, name);
            return this;
        }
    }

    public class xWebstoreBuyerGroup extends DomainBuilder {
        public xWebstoreBuyerGroup(xWebstore webstore, xBuyerGroup buyerGroup) {
            super(WebStoreBuyerGroup.SObjectType);
            setParent(WebStoreBuyerGroup.WebStoreId, webstore);
            setParent(WebStoreBuyerGroup.BuyerGroupId, buyerGroup);
        }
    }

    public class xBuyerAccount extends DomainBuilder {
        public xBuyerAccount(xAccount buyer) {
            super(BuyerAccount.SObjectType);

            set(BuyerAccount.IsActive, true);
            set(BuyerAccount.Name, 'testBuyerAccount' + nameIndex++);
            setParent(BuyerAccount.BuyerId, buyer);
        }

        public xBuyerAccount active(Boolean isActive) {
            set(BuyerAccount.IsActive, isActive);
            return this;
        }

        public xBuyerAccount name(String name) {
            set(BuyerAccount.Name, name);
            return this;
        }
    }

    public class xEntitlementPolicy extends DomainBuilder {
        public xEntitlementPolicy() {
            super(CommerceEntitlementPolicy.SObjectType);

            set(CommerceEntitlementPolicy.IsActive, true);
            name('TestPolicy' + nameIndex++);
        }

        public xEntitlementPolicy name(String name) {
            set(CommerceEntitlementPolicy.Name, name);
            return this;
        }

        public xEntitlementPolicy canViewProduct(Boolean canViewProduct) {
            set(CommerceEntitlementPolicy.CanViewProduct, canViewProduct);
            return this;
        }

        public xEntitlementPolicy canViewPrice(Boolean canViewPrice) {
            set(CommerceEntitlementPolicy.CanViewPrice, canViewPrice);
            return this;
        }

        public xEntitlementPolicy active(Boolean isActive) {
            set(CommerceEntitlementPolicy.IsActive, isActive);
            return this;
        }
    }

    public class xEntitlementBuyerGroup extends DomainBuilder {
        public xEntitlementBuyerGroup(xBuyerGroup buyerGroup, xEntitlementPolicy policy) {
            super(CommerceEntitlementBuyerGroup.SObjectType);

            setParent(CommerceEntitlementBuyerGroup.BuyerGroupId, buyerGroup);
            setParent(CommerceEntitlementBuyerGroup.PolicyId, policy);
        }
    }

    public class xEntitlementProduct extends DomainBuilder {
        public xEntitlementProduct(xProduct product, xEntitlementPolicy policy) {
            super(CommerceEntitlementProduct.SObjectType);

            setParent(CommerceEntitlementProduct.ProductId, product);
            setParent(CommerceEntitlementProduct.PolicyId, policy);
        }
    }

    public class xPricebook extends DomainBuilder {
        public xPricebook() {
            super(Pricebook2.SObjectType);

            set(Pricebook2.IsActive, true);
            name('testPricebook' + nameIndex++);
        }

        public xPricebook name(String name) {
            set(Pricebook2.Name, name);
            return this;
        }

        public xPricebook validFrom(Date v) {
            set(Pricebook2.ValidFrom, v);
            return this;
        }

        public xPricebook validTo(Date v) {
            set(Pricebook2.ValidTo, v);
            return this;
        }

        public xPricebook active(Boolean isActive) {
            set(Pricebook2.IsActive, isActive);
            return this;
        }
    }

    public class xBuyerGroupPricebook extends DomainBuilder {
        public xBuyerGroupPricebook(xBuyerGroup buyerGroup, xPricebook pricebook) {
            super(BuyerGroupPricebook.SObjectType);

            setParent(BuyerGroupPricebook.BuyerGroupId, buyerGroup);
            setParent(BuyerGroupPricebook.Pricebook2Id, pricebook);
            set(BuyerGroupPricebook.IsActive, true);
        }

        public xBuyerGroupPricebook priority(Integer v) {
            set(BuyerGroupPricebook.Priority, v);
            return this;
        }
    }

    public class xPricebookEntry extends DomainBuilder {
        public xPricebookEntry() {
            this(new xProduct(), new xPricebook());
        }

        public xPricebookEntry(xProduct product, xPricebook pricebook) {
            super(PricebookEntry.SObjectType);

            setParent(PricebookEntry.Product2Id, product);
            setParent(PricebookEntry.Pricebook2Id, pricebook);
            price(10);
        }

        public xPricebookEntry price(Decimal unitPrice) {
            set(PricebookEntry.UnitPrice, unitPrice);
            return this;
        }

        public xPricebookEntry active() {
            set(PricebookEntry.isActive, true);
            return this;
        }
    }

    public class xStandardPricebookEntry extends DomainBuilder {
        public xStandardPricebookEntry(xProduct product) {
            super(PricebookEntry.SObjectType);
            setParent(PricebookEntry.Product2Id, product);
            set(PricebookEntry.Pricebook2Id, Test.getStandardPricebookId());
            price(10);
        }

        public xStandardPricebookEntry price(Decimal unitPrice) {
            set(PricebookEntry.UnitPrice, unitPrice);
            return this;
        }

        public xStandardPricebookEntry active() {
            set(PricebookEntry.isActive, true);
            return this;
        }
    }

    public class xElectronicMediaGroup extends DomainBuilder {
        public xElectronicMediaGroup() {
            super(ElectronicMediaGroup.SObjectType);

            name('ProductTestImage');
            description('test_description');
            usageType('Standard');
        }

        public xElectronicMediaGroup name(String name) {
            set(ElectronicMediaGroup.Name, name);
            set(ElectronicMediaGroup.DeveloperName, name);
            return this;
        }

        public xElectronicMediaGroup description(String v) {
            set(ElectronicMediaGroup.Description, v);
            return this;
        }

        public xElectronicMediaGroup usageType(String v) {
            set(ElectronicMediaGroup.UsageType, v);
            return this;
        }
    }

    public class xContactPointAddress extends DomainBuilder {
        public xContactPointAddress() {
            super(ContactPointAddress.SObjectType);

            set(ContactPointAddress.Name, 'Test Contact Point');
            set(ContactPointAddress.Street, '800 River Road');
            set(ContactPointAddress.StateCode, 'NJ');
            set(ContactPointAddress.City, 'Fair Haven');
            set(ContactPointAddress.PostalCode, '07704');
            set(ContactPointAddress.CountryCode, 'US');
        }

        public xContactPointAddress parent(xAccount account) {
            setParent(ContactPointAddress.ParentId, account);
            return this;
        }

        public xContactPointAddress addressType(String v) {
            set(ContactPointAddress.AddressType, v);
            return this;
        }

        public xContactPointAddress isDefault(Boolean v) {
            set(ContactPointAddress.IsDefault, v);
            return this;
        }
    }

    public class xCart extends DomainBuilder {
        public xCartDeliveryGroup deliveryGroup { get; private set; }
        public List<CartItem> cartItems { get; private set; }

        public xCart() {
            super(WebCart.SObjectType);

            this.cartItems = new List<CartItem>();

            set(WebCart.Name, 'Test Cart' + nameIndex++);
            setParent(WebCart.WebStoreId, new xWebstore());
            setParent(WebCart.AccountId, new xAccount());

            this.deliveryGroup = new xCartDeliveryGroup(this);
        }

        private xCart withItem(xCartItem item) {
            CartItem record = (CartItem) item.getRecord();
            cartItems.add(record);

            return this;
        }

        public xCart withItem() {
            return withItem(new xCartItem(this));
        }

        public xCart withItem(xProduct product, Decimal price, Integer qty) {
            return withItem(new xCartItem(this).product(product, price, qty));
        }

        public xCart webstore(xWebstore webstore) {
            setParent(WebCart.WebStoreId, webstore);
            return this;
        }

        public xCart status(String v) {
            set(WebCart.Status, v);
            return this;
        }

        public xCart account(xAccount account) {
            setParent(WebCart.AccountId, account);
            return this;
        }
    }

    public class xCartItem extends DomainBuilder {
        public xCartItem(xCart cart) {
            super(CartItem.SObjectType);

            set(CartItem.Name, 'Cart Item Test' + nameIndex++);
            setParent(CartItem.CartId, cart);
            setParent(CartItem.CartDeliveryGroupId, cart.deliveryGroup);
        }

        public xCartItem product(xProduct product, Decimal price, Integer qty) {
            setParent(CartItem.Product2Id, product);
            set(CartItem.Quantity, qty);
            set(CartItem.ListPrice, price);
            set(CartItem.SalesPrice, price);
            set(CartItem.TotalPrice, price * qty);
            set(CartItem.TotalLineAmount, price * qty);

            return this;
        }
    }

    public class xProductCategory extends DomainBuilder {
        public xProductCategory(Id productCatalogId) {
            super(ProductCategory.SObjectType);

            set(ProductCategory.Name, 'Product Category Test' + nameIndex++);
            set(ProductCategory.CatalogId, productCatalogId);
        }

        public xProductCategory name(String v) {
            set(ProductCategory.Name, v);
            return this;
        }

        public xProductCategory withParent(Id parentCategoryId) {
            set(ProductCategory.ParentCategoryId, parentCategoryId);
            return this;
        }
    }

    public class xProductCatalog extends DomainBuilder {
        public xProductCatalog() {
            super(ProductCatalog.SObjectType);

            set(ProductCatalog.Name, 'Product Catalog Test' + nameIndex++);
        }
    }
    public class xProductCategoryProduct extends DomainBuilder {
        public xProductCategoryProduct(Id productId, Id categoryId) {
            super(ProductCategoryProduct.SObjectType);

            set(ProductCategoryProduct.ProductId, productId);
            set(ProductCategoryProduct.ProductCategoryId, categoryId);
        }
    }

    public class xCartDeliveryGroup extends DomainBuilder {
        public xCartDeliveryGroup(xCart cart) {
            super(CartDeliveryGroup.SObjectType);

            set(CartDeliveryGroup.Name, 'Cart Delivery Group' + nameIndex++);
            setParent(CartDeliveryGroup.CartId, cart);
        }
    }

    public class xCartCheckoutSession extends DomainBuilder {
        public xCartCheckoutSession(xCart cart) {
            super(CartCheckoutSession.SObjectType);

            set(CartCheckoutSession.Name, 'Cart Checkout Session ' + nameIndex++);
            setParent(CartCheckoutSession.WebCartId, cart);
            set(CartCheckoutSession.State, 'Start');
            set(CartCheckoutSession.IsArchived, false);
        }
    }
    public class xPriceAdjustmentSchedule extends DomainBuilder {
        public xPriceAdjustmentSchedule() {
            super(PriceAdjustmentSchedule.SObjectType);

            set(PriceAdjustmentSchedule.Name, 'TEST' + nameIndex++);
        }

        public xPriceAdjustmentSchedule createAdjustment(xPricebookEntry entry) {
            new xPricebookEntryAdjustment(this, entry);
            new xPriceAdjustmentTier(this).lower(0).upper(50).typePercentage().value(0.2);

            return this;
        }
    }

    public class xPricebookEntryAdjustment extends DomainBuilder {
        public xPricebookEntryAdjustment(xPriceAdjustmentSchedule schedule, xPricebookEntry entry) {
            super(PricebookEntryAdjustment.SObjectType);
            setParent(PricebookEntryAdjustment.PriceAdjustmentScheduleId, schedule);
            setParent(PricebookEntryAdjustment.PricebookEntryId, entry);
        }
    }

    public class xPriceAdjustmentTier extends DomainBuilder {
        public xPriceAdjustmentTier(xPriceAdjustmentSchedule schedule) {
            super(PriceAdjustmentTier.SObjectType);
            setParent(PriceAdjustmentTier.PriceAdjustmentScheduleId, schedule);
        }

        public xPriceAdjustmentTier upper(Decimal v) {
            set(PriceAdjustmentTier.UpperBound, v);
            return this;
        }

        public xPriceAdjustmentTier lower(Decimal v) {
            set(PriceAdjustmentTier.LowerBound, v);
            return this;
        }

        public xPriceAdjustmentTier typePercentage() {
            set(PriceAdjustmentTier.TierType, 'AdjustmentPercentage');
            return this;
        }

        public xPriceAdjustmentTier typeAmount() {
            set(PriceAdjustmentTier.TierType, 'AdjustmentAmount');
            return this;
        }

        public xPriceAdjustmentTier value(Decimal v) {
            set(PriceAdjustmentTier.TierValue, v);
            return this;
        }
    }

    public class xWishlist extends DomainBuilder {
        public xWishlist() {
            this(new xWebstore(), new xAccount());
        }

        public xWishlist(xWebstore store, xAccount acc) {
            super(Wishlist.SObjectType);

            name('Wishlist ' + nameIndex++);
            setParent(Wishlist.WebStoreId, store);
            setParent(Wishlist.AccountId, acc);
            set(Wishlist.OwnerId, UserInfo.getUserId());
        }

        public xWishlist name(String name) {
            set(Wishlist.Name, name);
            return this;
        }

        public xWishlist account(xAccount acc) {
            setParent(Wishlist.AccountId, acc);
            return this;
        }

        public xWishlist webstore(xWebstore store) {
            setParent(Wishlist.WebStoreId, store);
            return this;
        }
    }

    public class xWishlistItem extends DomainBuilder {
        public xWishlistItem(xWishlist wlist) {
            super(WishlistItem.SObjectType);

            name('Wishlist Item ' + nameIndex++);
            setParent(WishlistItem.WishlistId, wlist);
            setParent(WishlistItem.Product2Id, new xProduct());
        }

        public xWishlistItem name(String name) {
            set(WishlistItem.Name, name);
            return this;
        }

        public xWishlistItem product(xProduct product) {
            setParent(WishlistItem.Product2Id, product);
            return this;
        }
    }
}