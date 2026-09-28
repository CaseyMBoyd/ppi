/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author jakub_cichacki/Forefront
 * @date 22.02.2024
 * @test
 **/

public with sharing class CheckoutController {
	public static final String COMMERCE_SETTING_DEVELOPER_NAME = 'PPI_Commerce';
	public static final String BUYER_PERMISSION_SET_DEVELOPER_NAME = 'PPI_Commerce_Base';
	private static final String STANDARD_SHIP_OPTION = 'Standard';

	@AuraEnabled
	public static Account fetchAccount(Id effectiveAccountId) {
		effectiveAccountId = effectiveAccountId ?? BuyerService.effectiveAccountId;

		return [
			SELECT Id,
				BillingStateCode,
				BillingCountryCode,
				BillingPostalCode,
				BillingStreet,
				BillingCity
			FROM Account
			WHERE Id =: effectiveAccountId
			LIMIT 1
		];
	}


	@AuraEnabled
	public static void updateShippingInformation(
		Id cartId,
		ThirdPartyAddress address,
		String carrier,
		String carrierAccountNumber,
		String logisticsInformation
	) {
		update new WebCart(
			Id = cartId,
			Third_Party_Billing_Company__c = address?.company,
			Third_Party_Billing_StateCode__c = address?.state,
			Third_Party_Billing_Street1__c = address?.street,
			Third_Party_Billing_City__c = address?.city,
			Third_Party_Billing_Postal_Code__c = address?.postalCode,
			Third_Party_Billing_Street2__c = address?.street2,
			Carrier__c = carrier,
			Carrier_Account_Number__c = carrierAccountNumber,
			Logistics_Information__c = logisticsInformation
		);
	}

	@AuraEnabled(Cacheable=true)
	public static List<OrderDeliveryMethod> getOrderDeliveryMethods(){
		try {
			return [SELECT Id, Name, Help_Text__c FROM OrderDeliveryMethod WHERE IsActive = true WITH SYSTEM_MODE];
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled(Cacheable=true)
	public static List<Shipping_Carrier__mdt> fetchShippingCarriers() {
		return Shipping_Carrier__mdt.getAll().values();
	}

	@AuraEnabled(Cacheable=true)
	public static Integer getShipDateDaysAvailable() {
		return Optional.of(
			Commerce_Setting__mdt.getInstance(COMMERCE_SETTING_DEVELOPER_NAME)?.Ship_Date_Days_Available__c?.intValue(),
			365
		);
	}

	@AuraEnabled(Cacheable=true)
	public static List<Date> fetchShippingBlackoutDates() {
		Integer daysCount = getShipDateDaysAvailable();
		return new WorkCalendarService().calculateDaysOffForUntil(daysCount);
	}

	@AuraEnabled
	public static void saveSplitShipmentApproval(Id cartId, Boolean isAllowed) {
		update new WebCart(
			Id = cartId,
			Allow_Split_Shipment__c = isAllowed
		);
	}

	@AuraEnabled
	public static void saveShipDateInformation(String option, Date shipDate) {
		Savepoint sp = Database.setSavepoint();

		try {
			List<CartDeliveryGroup> cartDeliveryGroups = [
				SELECT Id,
					Ship_Date__c,
					Ship_Option__c
				FROM CartDeliveryGroup
				WHERE CartId = :BuyerService.currentActiveCart.cartId
				WITH SYSTEM_MODE
			];

			for (CartDeliveryGroup deliveryGroup : cartDeliveryGroups) {
				deliveryGroup.Ship_Option__c = option;
				deliveryGroup.Ship_Date__c = STANDARD_SHIP_OPTION.equalsIgnoreCase(option) ? null : shipDate;
			}

			update as system cartDeliveryGroups;
		}
		catch (Exception ex) {
			Database.rollback(sp);
			throw new AuraHandledException(AuraHandledExceptionBuilder.buildClientMessage(ex));
		}
	}

	public class ThirdPartyAddress {
		@AuraEnabled public String company { get; set; }
		@AuraEnabled public String state { get; set; }
		@AuraEnabled public String street { get; set; }
		@AuraEnabled public String street2 { get; set; }
		@AuraEnabled public String city { get; set; }
		@AuraEnabled public String postalCode { get; set; }
	}
}