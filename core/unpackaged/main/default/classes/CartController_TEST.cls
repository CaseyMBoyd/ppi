/**
	* Copyright (c) 2023 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author jakub_cichacki/Forefront
	* @date 13.03.2023
	* @description Test class for CartController_TEST
**/
@IsTest
private class CartController_TEST {
    @IsTest
    static void testFetchCarts() {
        // when
        List<WebCart> webCarts = CartController.fetchCarts(null);

        // then
        Assert.isTrue(webCarts.isEmpty());
    }

    @IsTest
    static void createPrimaryCart_Failure() {
        // given
        Boolean exceptionThrown = false;

        // when
        try {
            CartController.createPrimaryCart(null, null);
        }
        catch (Exception ex) {
            exceptionThrown = true;
        }

        // then
        Assert.isTrue(exceptionThrown);
    }

    @IsTest
    static void makeCartPrimary_Failure() {
        // given
        Boolean exceptionThrown = false;

        // when
        try {
            CartController.makeCartPrimary(null);
        }
        catch (Exception ex) {
            exceptionThrown = true;
        }

        // then
        Assert.isTrue(exceptionThrown);
    }

    @IsTest
    static void deleteCarts_Success() {
        // given
        Boolean exceptionThrown = false;

        // when
        try {
            CartController.deleteCarts(new List<Id>{
                b2btd.generateFakeId(WebCart.SObjectType)
            });
        }
        catch (Exception ex) {
            exceptionThrown = true;
        }

        // then
        Assert.isFalse(exceptionThrown);
    }

    @IsTest
    static void deleteCart_Failure() {
        // given
        Boolean exceptionThrown = false;

        // when
        try {
            CartController.deleteCart(b2btd.generateFakeId(WebCart.SObjectType));
        }
        catch (Exception ex) {
            exceptionThrown = true;
        }

        // then
        Assert.isTrue(exceptionThrown);
    }

    @IsTest
    static void testUpdateCartName() {
        // given
        final String newCartName = 'MY_NEW_CART_NAME';
        b2btd.xCart cart = new b2btd.xCart();
        cart.persist();

        // when
        CartController.updateCartNames(new List<WebCart>{new WebCart(Id = cart.id, Name = newCartName)});

        // then
        Assert.areEqual(newCartName, [SELECT Name FROM WebCart WHERE Id = :cart.id LIMIT 1].Name);
    }

    @IsTest
    static void testIsCartEmpty() {
        // given
        b2btd.xCart cart = new b2btd.xCart();
        cart.persist();

        // when
        Boolean isCartEmpty = CartController.isCartEmpty();

        // then
        Assert.isTrue(isCartEmpty);
    }
}