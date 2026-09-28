/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 16.03.2024
 * @description Test suite
 *
 */

@IsTest
public class CartDocumentUploadController_TEST {
	@IsTest
	static void testBehavior() {
        // given
        WebCart cart = arrangeCart();
        CartDocumentUploadController.FileWrapper fileInput = arrangeFileInput(cart);

        // when
        CartDocumentUploadController.createCartDocument(fileInput);

        // then
        List<CartDocumentUploadController.FileWrapper> createdDocuments =
            CartDocumentUploadController.fetchCartDocuments(cart.Id);

        Assert.areEqual(1, createdDocuments.size(), 'Should attach one document');

        // when
        CartDocumentUploadController.deleteCartDocument(createdDocuments[0].cartDocumentId);
        createdDocuments = CartDocumentUploadController.fetchCartDocuments(cart.Id);

        // then
        Assert.areEqual(0, createdDocuments.size(), 'Attached document should be removed');
    }

    public static CartDocumentUploadController.FileWrapper arrangeFileInput(WebCart cart) {
        CartDocumentUploadController.FileWrapper fileInput = new CartDocumentUploadController.FileWrapper();
        fileInput.name = 'test.txt';
        fileInput.mimeType = 'text/plain';
        fileInput.cartId = cart.Id;
        fileInput.base64content = 'test';
        return fileInput;
    }


    public static WebCart arrangeCart() {
        WebStore store = new WebStore(
            Name = 'test'
        );
        insert store;

        Account account = new Account(
            Name = 'account'
        );
        insert account;

        WebCart cart = new WebCart(
            AccountId = account.Id,
            WebStoreId = store.Id,
            Name = 'Test Cart'
        );

        insert cart;
        return cart;
    }
}