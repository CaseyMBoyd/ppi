/**
 * Copyright (c) 2023 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author jakub_cichacki/Forefront
 * @date 13.03.2023
 * @description
 **/

global without sharing class BuyerService {
    private static final IBuyerContext context = BuyerContext.getInstance();
    @TestVisible
    private static ConnectApi.CartSummary mockCartSummary;

    public static Account effectiveAccount {
        get {
            return context.getEffectiveAccount();
        }
    }

    public static Id effectiveAccountId {
        get {
            return context.getEffectiveAccountId();
        }
    }

    public static String currentWebStoreId {
        get {
            return context.getWebstore().Id;
        }
    }

    public static Contact currentContact {
        get {
            return context.getContact();
        }
    }

    public static ConnectApi.CartSummary currentActiveCart {
        get {
            if (currentActiveCart == null) {
                currentActiveCart = Test.isRunningTest()
                    ? mockCartSummary
                    : ConnectApi.CommerceCart.getOrCreateActiveCartSummary(BuyerService.currentWebStoreId, BuyerService.effectiveAccountId, 'active');
            }
            return currentActiveCart;
        }
        set;
    }
}