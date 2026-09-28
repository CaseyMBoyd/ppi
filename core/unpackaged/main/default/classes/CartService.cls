/**
	* Copyright (c) 2023 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author jakub_cichacki/Forefront
	* @date 13.03.2023
	* @description
**/

public with sharing class CartService {
    private static CartService instance;

    @TestVisible private static ConnectApi.CartSummary mockCartSummary;

    public static CartService getInstance() {
        if (instance == null) {
            instance = (CartService) ServiceFactory.get(CartService.class);
        }

        return instance;
    }

    public List<WebCart> getCarts(Id effectiveAccountId) {
        effectiveAccountId = effectiveAccountId ?? BuyerService.effectiveAccountId;

        Set<String> activeCartStatuses = new Set<String>{
                'Active', 'Checkout'
        };

        List<WebCart> activeCarts = new List<WebCart>();
        List<WebCart> cartsToUpdate = new List<WebCart>();

        String buyerManagerPermissionSetGroupDevName = 'PPI_Commerce_Buyer_Manager';
        String superViewerPermissionSetGroupDevName = 'PPI_Commerce_Super_Viewer';

        Boolean isBuyerManager = [
                SELECT Id
                FROM PermissionSetAssignment
                WHERE (PermissionSetGroup.DeveloperName =: buyerManagerPermissionSetGroupDevName 
                OR PermissionSetGroup.DeveloperName =: superViewerPermissionSetGroupDevName)
                AND AssigneeId = :UserInfo.getUserId()
                AND IsActive = TRUE
        ].size() > 0;



        Query cartQuery = new Query(WebCart.SObjectType)
                .selectFields('IsSecondary,Name,GrandTotalAmount,TotalProductCount,Status,CreatedDate,Owner.FirstName,Owner.LastName, OwnerId')
                .addSubquery(Query.subquery('CartItems')
                        .selectFields('Product2Id')
                )
                .addConditionIn(WebCart.Status, activeCartStatuses)
                .addConditionEq(WebCart.AccountId, effectiveAccountId)
                .orderBy('CreatedDate', 'ASC');

        if(!isBuyerManager) {

            List<WebCartShare> originallyOwnedCarts = [
                SELECT ParentId
                FROM WebCartShare
                WHERE UserOrGroupId =: UserInfo.getUserId()
                AND Parent.Status IN :activeCartStatuses
                WITH SYSTEM_MODE
            ];

            if(!originallyOwnedCarts.isEmpty()) {
                Set<Id> cartIds = Stream.of(originallyOwnedCarts).toSetOfIds(WebCartShare.ParentId);

                List<Query.Condition> orConditions = new List<Query.Condition>{
                    Query.conditionEq(WebCart.OwnerId, UserInfo.getUserId()),
                    Query.conditionIn(WebCart.Id, cartIds)
                };

                cartQuery.addCondition(Query.doOr(orConditions));
            }
            else {
                cartQuery.addConditionEq(WebCart.OwnerId, UserInfo.getUserId());
            }

        }

        for (WebCart cart : Database.query(cartQuery.toQueryString())) {
            if (cart.Status == 'Checkout') {
                cart.Status = 'Active';
                cartsToUpdate.add(cart);
            }
            activeCarts.add(cart);
        }

        update cartsToUpdate;
        return activeCarts;
    }

    public void makeCartPrimary(Id cartId) {
        WebCart currentCart = [
            SELECT AccountId,
                OwnerId,
                IsSecondary
            FROM WebCart
            WHERE Id =: cartId
            WITH SYSTEM_MODE
        ];

        removeAllPrimaryCartsForCurrentUser(currentCart.AccountId);

        final Id newOwnerId = UserInfo.getUserId();
        final Id oldOwnerId = currentCart.OwnerId;

        if(oldOwnerId != newOwnerId) {
            handleCartOwnerChange(currentCart.Id, newOwnerId, oldOwnerId);
        }


        if(currentCart.IsSecondary) {
            ConnectApi.CommerceCart.makeCartPrimary(
                BuyerService.currentWebStoreId,
                cartId,
                currentCart.AccountId
            );
        }
    }

    private void handleCartOwnerChange(Id cartId, Id newOwnerId, Id oldOwnerId) {
        ElevatedPermissions elevatedPermissions = new ElevatedPermissions();

        WebCart cart = new WebCart(
            Id = cartId,
            OwnerId = newOwnerId
        );

        elevatedPermissions.updateRecord(cart, true);

        String buyerManagerPermissionSetGroupDevName = 'PPI_Commerce_Buyer_Manager';

        Boolean isBuyerManager = ![
            SELECT Id
            FROM PermissionSetAssignment
            WHERE PermissionSetGroup.DeveloperName =: buyerManagerPermissionSetGroupDevName
            AND AssigneeId = :UserInfo.getUserId()
            AND IsActive = TRUE
        ].isEmpty();

        if(isBuyerManager) {

            WebCartShare shareWithOriginalOwner = new WebCartShare(
                ParentId = cartId,
                UserOrGroupId = oldOwnerId,
                AccessLevel = 'Edit',
                RowCause = 'Manual'
            );

            elevatedPermissions.insertRecord(shareWithOriginalOwner, false);
        }

        elevatedPermissions.deleteExistingCartCheckoutSessions(cartId);
    }

    public void removeAllPrimaryCartsForCurrentUser(Id accountId) {
        List<WebCart> carts = getCarts(accountId);
        List<WebCart> cartsToUpdate = new List<WebCart>();

        for(WebCart wc : carts) {
            if(wc.OwnerId == UserInfo.getUserId()) {
                wc.IsSecondary = true;
                cartsToUpdate.add(wc);
            }
        }

        update as system cartsToUpdate;
    }

    public ConnectApi.CartSummary createCart(String name, Id accountId) {
        ConnectApi.CartInput input = new ConnectApi.CartInput();

        input.effectiveAccountId = accountId ?? BuyerService.effectiveAccountId;
        input.isSecondary = true;
        input.name = name;


        return Test.isRunningTest()
            ? mockCartSummary
            : ConnectApi.CommerceCart.createCart(BuyerService.currentWebStoreId, input);
    }

    public ConnectApi.CartSummary createCart(String name) {
        return createCart(name, BuyerService.effectiveAccountId);
    }

    public void deleteCart(Id cartId) {
        ConnectApi.CommerceCart.deleteCart(
                BuyerService.currentWebStoreId,
                BuyerService.effectiveAccountId,
                cartId
        );
    }

    public void deleteCarts(List<Id> cartIds) {
        delete [SELECT Id FROM WebCart WHERE Id IN :cartIds];
    }

    public Id getPrimaryCartId() {
        return [SELECT Id FROM WebCart WHERE IsSecondary = FALSE AND OwnerId =: UserInfo.getUserId() LIMIT 1].Id;
    }

    public Boolean isCartEmpty(Id cartId) {
        return [SELECT COUNT() FROM CartItem WHERE CartId = :cartId] == 0;
    }


    public without sharing class ElevatedPermissions {

        public void insertRecord(SObject record, Boolean allOrNothing) {
            Database.insert(record, allOrNothing, AccessLevel.SYSTEM_MODE);
        }

        public void updateRecord(SObject record, Boolean allOrNothing) {
            Database.update(record, allOrNothing, AccessLevel.SYSTEM_MODE);
        }

        public void deleteExistingCartCheckoutSessions(Id cartId) {
            Database.delete([
                SELECT Id
                FROM CartCheckoutSession
                WHERE WebCartId = :cartId
                WITH SYSTEM_MODE
            ], false, AccessLevel.SYSTEM_MODE);
        }
    }
}