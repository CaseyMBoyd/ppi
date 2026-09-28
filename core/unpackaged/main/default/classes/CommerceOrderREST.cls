/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 14.03.2024 <p/>
 * @test CommerceOrderREST_TEST
 *
 */

@RestResource(UrlMapping='/commerce/order/*')
global without sharing class CommerceOrderREST {

	public static final SObjectField EXTERNAL_ID_ORDER = Order.External_Id__c;
	public static final SObjectField EXTERNAL_ID_ORDER_ITEM = OrderItem.External_Id__c;
	public static final SObjectField EXTERNAL_ID_PRODUCT = Product2.external_ID__c;
	public static final SObjectField EXTERNAL_ID_ACCOUNT = Account.externalId__c;

	public static final Commerce_Setting__mdt COMMERCE_SETTING = Commerce_Setting__mdt.getInstance('PPI_Commerce');

	@HttpDelete
	global static OperationResult doDelete() {
		OperationResult result = new OperationResult();
		Id orderId;

		try {
			RestRequest req = RestContext.request;

			final String orderExternalOrSfId = req.requestURI.substringAfterLast('/');

			orderId = [
				SELECT Id
				FROM Order
				WHERE External_Id__c =: orderExternalOrSfId
				OR Id =: orderExternalOrSfId
				LIMIT 1
			]?.Id;

			if(String.isBlank(orderId)) {
				result.error = 'Order with external or sf id of: \'' + orderExternalOrSfId + '\' not found in the org.';
				result.success = false;

				return result;
			}

			delete as system [
				SELECT Id FROM OrderSummary
				WHERE OriginalOrderId =: orderId
			];

			update as system new Order(Id = orderId, Status = 'Draft');

			delete as system [
				SELECT Id FROM Order
				WHERE Id =: orderId
			];

			result.success = true;
			result.orderId = orderId;
		}
		catch (Exception ex) {
			Logger.error('Order Delete Error', ex).setRecord(orderId);
			result.success = false;
			result.error = ex.getMessage();
		}
		finally {
			Logger.saveLog();
		}

		return result;
	}

	@HttpPost
	global static OperationResult process() {
		Savepoint sp = Database.setSavepoint();
		OperationResult result = new OperationResult();
		Id processingOrderID;

		try {
			OrderRequest input = deserializeRequestBody();
			processingOrderID = input.orderChange.Id;

			Logger.info(new LogMessage('Order Change Input {0}', RestContext.request.requestBody.toString()))
				.setRecord(processingOrderID);

			OrderActivator activator = new OrderActivator(input);

			if (activator.isBrandNewExternalOrder) {
				activator.input.orderChange.Status = 'Draft';
				activator.input.orderChange.SalesStoreId = [
					SELECT Id
					FROM WebStore
					WHERE Name = 'PPI Customer Portal'
					LIMIT 1
				]?.Id;
				insert activator.input.orderChange;

				Id orderDeliveryMethodId = fetchOrCreateOrderDeliveryMethod(new List<OrderRequest>{activator.input}).values()[0];

				OrderDeliveryGroup deliveryGroup = new OrderDeliveryGroup(
					DeliverToName = 'DEFAULT DELIVERY',
					DeliverToStreet = activator.input.orderChange.ShippingStreet,
					DeliverToCity = activator.input.orderChange.ShippingCity,
					DeliverToState = activator.input.orderChange.ShippingState,
					DeliverToPostalCode = activator.input.orderChange.ShippingPostalCode,
					DeliverToCountry = activator.input.orderChange.ShippingCountry,
					OrderDeliveryMethodId = orderDeliveryMethodId,
					OrderId = activator.input.orderChange.Id
				);
				insert deliveryGroup;

				processOrderLines(activator.input.orderChange.OrderItems);
				ensureDeliveryGroupOnOrderItems(activator.input.orderChange.OrderItems, deliveryGroup.Id);
				insert activator.input.orderChange.OrderItems;

				activator.input.orderChange.Status = activator.postProcessStatus;
				update activator.input.orderChange;

				activator.reFetchOrder();
				activator.activate();


				result.orderSummaryId = activator.regenerateOrderSummary();
				activator.populateResultOrderIds(result);

				result.success = true;

				return result;
			}

			activator.deactivate();
			activator.removeOrderSummary();

			Database.upsert(activator.input.orderChange, EXTERNAL_ID_ORDER);

			Map<String, SObject> currentLinesByExternalId = Stream.of(activator.originalOrder.OrderItems)
				.toMap(EXTERNAL_ID_ORDER_ITEM);

			Set<String> currentLinesExternalIds = currentLinesByExternalId.keySet();

			Set<String> itemsToRemoveExternalIds = new Set<String>(currentLinesExternalIds);

			// using iterator so that we dont have to rely on the passed `totalSize` from payload
			Iterator<OrderItem> changedItemsIterator = activator.input.orderChange.OrderItems.iterator();

			while (changedItemsIterator.hasNext()) {
				OrderItem changedItem = changedItemsIterator.next();
				final String externalID = (String) changedItem.get(EXTERNAL_ID_ORDER_ITEM);
				itemsToRemoveExternalIds.remove(externalID);
			}


			if (!itemsToRemoveExternalIds.isEmpty()) {
				delete Database.queryWithBinds(
					String.format(
						'SELECT Id FROM OrderItem WHERE {0} IN: itemsExternalIds AND {1} =: orderExternalId',
						new List<String>{
							String.valueOf(EXTERNAL_ID_ORDER_ITEM),
							'Order.' + String.valueOf(EXTERNAL_ID_ORDER)
						}
					),
					new Map<String, Object>{
						'itemsExternalIds' => itemsToRemoveExternalIds,
						'orderExternalId' => activator.input.orderChange.get(EXTERNAL_ID_ORDER)
					},
					AccessLevel.SYSTEM_MODE
				);
			}

			List<OrderItem> itemsToUpsert = new List<OrderItem>();

			changedItemsIterator = activator.input.orderChange.OrderItems.iterator();

			while (changedItemsIterator.hasNext()) {
				OrderItem changedItem = changedItemsIterator.next();

				String externalId = (String) changedItem.get(EXTERNAL_ID_ORDER_ITEM);

				Boolean isUpdate = currentLinesExternalIds.contains(externalId);
				Boolean wasRemoved = itemsToRemoveExternalIds.contains(externalId);

				if (isUpdate && !wasRemoved) {
					itemsToUpsert.add((OrderItem) stripInaccessibleFieldsForUpdate(changedItem));
				}
				else {
					itemsToUpsert.add(changedItem);
				}
			}

			processOrderLines(itemsToUpsert);
			ensureDeliveryGroupOnOrderItems(
				itemsToUpsert,
				activator.originalOrder.OrderDeliveryGroups[0].Id
			);

			Database.upsert(
				itemsToUpsert,
				EXTERNAL_ID_ORDER_ITEM
			);

			activator.activate();
			result.orderSummaryId = activator.regenerateOrderSummary();
			activator.populateResultOrderIds(result, itemsToUpsert);

			result.success = true;
		}
		catch (Exception ex) {
			Logger.error('Order Change Error', ex).setRecord(processingOrderID);

			Database.rollback(sp);
			result.success = false;
			result.error = ex.getMessage();
		}
		finally {
			Logger.saveLog();
		}

		return result;
	}

	@HttpPatch
	global static List<OperationResult> doPatch() {
		Savepoint sp = Database.setSavepoint();
		List<OperationResult> result = new List<OperationResult>();

		try {
			Logger.info('Order Change Bulk Request').setRestRequestDetails(RestContext.request);

			List<OrderRequest> input = (List<OrderRequest>) JSON.deserializeStrict(
					RestContext.request.requestBody.toString(),
					List<OrderRequest>.class
			);

			Id webstoreId = [
					SELECT Id
					FROM WebStore
					WHERE Name = 'PPI Customer Portal'
					LIMIT 1
			]?.Id;

			Map<String, Id> orderDeliveryMethodIdsByName = fetchOrCreateOrderDeliveryMethod(input);
			Map<Boolean, List<OrderActivator>> orderActivatorsByIsNewOrder = prepareActivatorsMap(input);
			List<OrderActivator> activatorsForBrandNewExtOrders = orderActivatorsByIsNewOrder.get(true);
			List<OrderActivator> activatorsForChangeOrder = orderActivatorsByIsNewOrder.get(false);

			List<Order> toInsert = new List<Order>();
			for (OrderActivator activator : activatorsForBrandNewExtOrders) {
				activator.input.orderChange.Status = 'Draft';
				activator.input.orderChange.SalesStoreId = webstoreId;
				toInsert.add(activator.input.orderChange);
			}

			List<Database.SaveResult> saveResults = Database.insert(toInsert, false, AccessLevel.SYSTEM_MODE);


			Map<Id, OrderDeliveryGroup> deliveryGroupsByOrderId = new Map<Id, OrderDeliveryGroup>();
			for (Integer i = 0; i < activatorsForBrandNewExtOrders.size(); i++) {
				if (!saveResults[i].success) {
					continue;
				}

				OrderActivator activator = activatorsForBrandNewExtOrders[i];
				OrderRequest request = activator.input;

				OrderDeliveryGroup deliveryGroup = new OrderDeliveryGroup(
						DeliverToName = 'DEFAULT DELIVERY',
						DeliverToStreet = request.orderChange.ShippingStreet,
						DeliverToCity = request.orderChange.ShippingCity,
						DeliverToState = request.orderChange.ShippingState,
						DeliverToPostalCode = request.orderChange.ShippingPostalCode,
						DeliverToCountry = request.orderChange.ShippingCountry,
						OrderDeliveryMethodId = orderDeliveryMethodIdsByName.get(request.orderChange.Ship_Via__c ?? 'PPI Selects'),
						OrderId = request.orderChange.Id
				);

				deliveryGroupsByOrderId.put(request.orderChange.Id, deliveryGroup);
			}

			insert as system deliveryGroupsByOrderId.values();

			Map<Id, List<OrderItem>> orderItemsByOrderId = new Map<Id, List<OrderItem>>();
			for (Integer i = 0; i < activatorsForBrandNewExtOrders.size(); i++) {
				if (!saveResults[i].success) {
					continue;
				}

				OrderActivator activator = activatorsForBrandNewExtOrders[i];
				OrderRequest request = activator.input;
				orderItemsByOrderId.put(request.orderChange.Id, request.orderChange.OrderItems);
			}

			processOrderLines(orderItemsByOrderId);

			List<OrderItem> orderItemsToInsert = new List<OrderItem>();
			for (Id orderId : orderItemsByOrderId.keySet()) {
				ensureDeliveryGroupOnOrderItems(orderItemsByOrderId.get(orderId), deliveryGroupsByOrderId.get(orderId).Id);
				orderItemsToInsert.addAll(orderItemsByOrderId.get(orderId));
			}

			insert orderItemsToInsert;

			List<Order> toUpdate = new List<Order>();
			Set<String> ordersExternalIds = new Set<String>();

			for (Integer i = 0; i < activatorsForBrandNewExtOrders.size(); i++) {
				if (!saveResults[i].success) {
					continue;
				}

				OrderActivator activator = activatorsForBrandNewExtOrders[i];
				activator.input.orderChange.Status = activator.postProcessStatus;
				toUpdate.add(activator.input.orderChange);
				ordersExternalIds.add((String) activator.input.orderChange.get(EXTERNAL_ID_ORDER));
			}

			update as system toUpdate;

			toUpdate = new List<Order>();
			for (Integer i = 0; i < activatorsForBrandNewExtOrders.size(); i++) {
				if (!saveResults[i].success) {
					continue;
				}

				OrderActivator activator = activatorsForBrandNewExtOrders[i];
				activator.originalOrder.Id = activator.input.orderChange.Id;
				toUpdate.add(new Order(
						Id = activator.originalOrder.Id,
						Status = activator.postProcessStatus
				));
			}

			update as system toUpdate;

			for (Integer i = 0; i < activatorsForBrandNewExtOrders.size(); i++) {
				OperationResult res = new OperationResult();

				if (!saveResults[i].success) {
					res.error = saveResults[i].getErrors()[0].getMessage();
					res.success = false;
					result.add(res);
				} else {
					OrderActivator activator = activatorsForBrandNewExtOrders[i];
					res.orderSummaryId = activator.regenerateOrderSummary();
					activator.populateResultOrderIds(res);

					res.success = true;
					result.add(res);
				}
			}

			List<Id> orderIds = new List<Id>();
			List<Order> toDeactivate = new List<Order>();
			List<Order> ordersToUpsert = new List<Order>();

			for (OrderActivator activator : activatorsForChangeOrder) {
				activator.originalOrder.Status = 'Draft';
				activator.input.orderChange.Status = 'Draft';
				orderIds.add(activator.originalOrder.Id);
				toDeactivate.add(new Order(Id = activator.originalOrder.Id, Status = activator.originalOrder.Status));
				ordersToUpsert.add(activator.input.orderChange);
			}

			update as system toDeactivate;
			delete as system [SELECT Id FROM OrderSummary WHERE OriginalOrderId IN :orderIds];

			List<Database.UpsertResult> upsertResults = Database.upsert(ordersToUpsert, EXTERNAL_ID_ORDER, false, AccessLevel.SYSTEM_MODE);

			Map<String, Set<String>> currentLinesExternalIds = new Map<String, Set<String>>();
			Set<String> itemsToRemoveExternalIds = new Set<String>();

			for (Integer i = 0; i < activatorsForChangeOrder.size(); i++) {
				if (!upsertResults[i].success) {
					continue;
				}

				OrderActivator activator = activatorsForChangeOrder[i];

				Map<String, SObject> currentLinesByExternalId = Stream.of(activator.originalOrder.OrderItems)
						.toMap(EXTERNAL_ID_ORDER_ITEM);

				currentLinesExternalIds.put(activator.originalOrder.External_Id__c, currentLinesByExternalId.keySet());
				itemsToRemoveExternalIds.addAll(currentLinesByExternalId.keySet());

				Iterator<OrderItem> changedItemsIterator = findOrderChange(input, activator.originalOrder.External_Id__c).orderChange.OrderItems.iterator();

				while (changedItemsIterator.hasNext()) {
					OrderItem changedItem = changedItemsIterator.next();
					final String externalID = (String) changedItem.get(EXTERNAL_ID_ORDER_ITEM);
					itemsToRemoveExternalIds.remove(externalID);
				}
			}
			itemsToRemoveExternalIds.remove(null);
			itemsToRemoveExternalIds.remove('');

			if (!itemsToRemoveExternalIds.isEmpty()) {
				delete Database.queryWithBinds(
						String.format(
								'SELECT Id FROM OrderItem WHERE {0} IN: itemsExternalIds',
								new List<String>{
										String.valueOf(EXTERNAL_ID_ORDER_ITEM)
								}
						),
						new Map<String, Object>{
								'itemsExternalIds' => itemsToRemoveExternalIds
						},
						AccessLevel.SYSTEM_MODE
				);
			}

			Map<Id, List<OrderItem>> itemsToUpsertByOrderId = new Map<Id, List<OrderItem>>();
			for (Integer i = 0; i < activatorsForChangeOrder.size(); i++) {
				List<OrderItem> actItems = new List<OrderItem>();
				if (!upsertResults[i].success) {
					continue;
				}

				OrderActivator activator = activatorsForChangeOrder[i];
				Iterator<OrderItem> changedItemsIterator = findOrderChange(input, activator.originalOrder.External_Id__c).orderChange.OrderItems.iterator();
				while (changedItemsIterator.hasNext()) {
					OrderItem changedItem = changedItemsIterator.next();

					String externalId = (String) changedItem.get(EXTERNAL_ID_ORDER_ITEM);

					Boolean isUpdate = currentLinesExternalIds.get(activator.originalOrder.External_Id__c).contains(externalId);
					Boolean wasRemoved = itemsToRemoveExternalIds.contains(externalId);

					if (isUpdate && !wasRemoved) {
						actItems.add((OrderItem) stripInaccessibleFieldsForUpdate(changedItem));
					} else {
						actItems.add(changedItem);
					}
				}

				processOrderLines(actItems);

				ensureDeliveryGroupOnOrderItems(
						actItems,
						activator.originalOrder.OrderDeliveryGroups[0].Id
				);

				itemsToUpsertByOrderId.put(activator.originalOrder.Id, actItems);
			}

			List<OrderItem> itemsToUpsert = new List<OrderItem>();
			for (List<OrderItem> items : itemsToUpsertByOrderId.values()) {
				itemsToUpsert.addAll(items);
			}

			Database.upsert(
					itemsToUpsert,
					EXTERNAL_ID_ORDER_ITEM
			);

			List<Order> toActivate = new List<Order>();
			for (Integer i = 0; i < activatorsForChangeOrder.size(); i++) {
				if (!upsertResults[i].success) {
					continue;
				}

				OrderActivator activator = activatorsForChangeOrder[i];
				activator.originalOrder.Status = activator.postProcessStatus;
				activator.input.orderChange.Status = activator.postProcessStatus;

				toActivate.add(new Order(Id = activator.originalOrder.Id, Status = activator.postProcessStatus));
			}

			update as system toActivate;

			for (Integer i = 0; i < activatorsForChangeOrder.size(); i++) {
				OperationResult res = new OperationResult();
				if (!upsertResults[i].success) {
					res.error = upsertResults[i].getErrors()[0].getMessage();
					res.success = false;
					result.add(res);
				} else {
					OrderActivator activator = activatorsForChangeOrder[i];
					res.orderSummaryId = activator.regenerateOrderSummary();
					res.orderId = activator.originalOrder.Id;
					res.success = true;
					activator.populateResultOrderIds(res, itemsToUpsertByOrderId.get(activator.originalOrder.Id));
					result.add(res);
				}
			}
		} catch (Exception ex) {
			Logger.error('Order Change Error', ex);
			Database.rollback(sp);
		} finally {
			Logger.saveLog();
		}

		return result;
	}

	private static Map<String, Id> fetchOrCreateOrderDeliveryMethod(List<OrderRequest> inputs) {
		Set<String> shipViaNames = new Set<String>();
		for(OrderRequest input: inputs) {
			shipViaNames.add(input.orderChange.Ship_Via__c ?? 'PPI Selects');
		}

		List<OrderDeliveryMethod> orderDeliveryMethods = [SELECT Id, Name FROM OrderDeliveryMethod WHERE Name IN :shipViaNames];
		Map<String, Id> orderDeliveryMethodIdByName = new Map<String, Id>();
		for(OrderDeliveryMethod odm : orderDeliveryMethods) {
			orderDeliveryMethodIdByName.put(odm.Name, odm.Id);
		}

		if(!orderDeliveryMethodIdByName.keySet().containsAll(shipViaNames)) {
			List<OrderDeliveryMethod> newOrderDeliveryMethods = new List<OrderDeliveryMethod>();
			for(String shipVia : shipViaNames) {
				if(!orderDeliveryMethodIdByName.containsKey(shipVia)) {
					shipVia = shipVia == '' ? 'Will Advise' : shipVia;
					OrderDeliveryMethod newOrderDeliveryMethod = new OrderDeliveryMethod(
							Name = shipVia,
							// need to be false, as we use it only for legacy order, we dont want it displayed in the store
							IsActive = false
					);

					newOrderDeliveryMethods.add(newOrderDeliveryMethod);
				}
			}
			insert as system newOrderDeliveryMethods;

			for(OrderDeliveryMethod newOrderDeliveryMethod : newOrderDeliveryMethods) {
				orderDeliveryMethodIdByName.put(newOrderDeliveryMethod.Name, newOrderDeliveryMethod.Id);
			}
		}

		return orderDeliveryMethodIdByName;
	}

	private static Map<Boolean, List<OrderActivator>> prepareActivatorsMap(List<OrderRequest> orderRequests) {
		Map<Boolean, List<OrderActivator>> activatorsByIsNewOrder = new Map<Boolean, List<OrderActivator>>{
			true => new List<OrderActivator>(),
			false => new List<OrderActivator>()
		};

		Set<String> orderExternalIds = new Set<String>();
		for(OrderRequest orderRequest : orderRequests) {
			orderExternalIds.add((String) orderRequest.orderChange.get(EXTERNAL_ID_ORDER));
		}

		List<Order> orders = fetchOrders(orderExternalIds);
		Map<String, SObject> ordersByExternalId = Stream.of(orders).toMap(EXTERNAL_ID_ORDER);

		for(OrderRequest orderRequest : orderRequests) {
			if(ordersByExternalId.containsKey((String) orderRequest.orderChange.get(EXTERNAL_ID_ORDER))) {
				activatorsByIsNewOrder.get(false).add(new OrderActivator(orderRequest, (Order) ordersByExternalId.get((String) orderRequest.orderChange.get(EXTERNAL_ID_ORDER))));
			} else {
				activatorsByIsNewOrder.get(true).add(new OrderActivator(orderRequest, new Order()));
			}
		}

		return activatorsByIsNewOrder;
	}

	private static List<Order> fetchOrders(Set<String> orderExternalIds) {
		return new Query(Order.SObjectType)
				.selectField(Order.Status)
				.selectField(Order.External_Id__c)
				.selectField('Account.' + String.valueOf(EXTERNAL_ID_ACCOUNT))
				.addSubquery(Query.subquery('OrderItems')
						.selectField(OrderItem.Id)
						.selectField(OrderItem.Product2Id)
						.selectField(EXTERNAL_ID_ORDER_ITEM)
						.selectField('Product2.' + EXTERNAL_ID_PRODUCT)
				)
				.addSubquery('OrderDeliveryGroups')
				.addConditionIn(EXTERNAL_ID_ORDER, orderExternalIds)
				.forUpdate()
				.run();
	}

	private static OrderRequest findOrderChange(List<OrderRequest> orderRequests, String externalId) {
		for(OrderRequest orderRequest : orderRequests) {
			if(orderRequest.orderChange.get(EXTERNAL_ID_ORDER) == externalId) {
				return orderRequest;
			}
		}

		return null;
	}

	private static void ensureDeliveryGroupOnOrderItems(List<OrderItem> items, Id deliveryGroupId) {
		for (OrderItem item : items) {
			item.OrderDeliveryGroupId = deliveryGroupId;
		}
	}

	private static void processOrderLines(List<OrderItem> items) {

		Set<String> externalProductIds = new Set<String>();

		Iterator<OrderItem> iterator = items.iterator();

		while (iterator.hasNext()) {
			OrderItem item = iterator.next();
			item.Type = item.Type ?? 'Order Product';
			externalProductIds.add(item?.Product2?.external_ID__c);
		}

		externalProductIds.remove(null);

		replaceProductsNotFoundWithGeneric(externalProductIds, iterator, items);
	}

	private static void processOrderLines(Map<Id,List<OrderItem>> itemsByOrderId) {
		Set<String> externalProductIds = new Set<String>();

		for(Id orderId : itemsByOrderId.keySet()) {
			List<OrderItem> items = itemsByOrderId.get(orderId);
			Iterator<OrderItem> iterator = items.iterator();

			while (iterator.hasNext()) {
				OrderItem item = iterator.next();
				item.Type = item.Type ?? 'Order Product';
				externalProductIds.add(item?.Product2?.external_ID__c);
			}
		}

		externalProductIds.remove(null);

		List<Product2> existingProducts = [
				SELECT Id,
						external_ID__c
				FROM Product2
				WHERE external_ID__c IN :externalProductIds
				WITH SYSTEM_MODE
		];

		Set<String> existingExternalProductIds = Stream.of(existingProducts).toSet(Product2.external_ID__c);
		for(Id orderId : itemsByOrderId.keySet()) {
			List<OrderItem> items = itemsByOrderId.get(orderId);

			Iterator<OrderItem> iterator = items.iterator();
			while (iterator.hasNext()) {
				OrderItem item = iterator.next();
				externalProductIds.add(item?.Product2?.external_ID__c);

				if (item.Product2 != null && !existingExternalProductIds.contains(item.Product2.external_ID__c)) {
					item.Description__c = item.Description__c ?? item.Product2.external_ID__c;
					item.Product2.external_ID__c = COMMERCE_SETTING.Generic_Product_External_Id__c;
				}
			}
		}
	}

	private static void replaceProductsNotFoundWithGeneric(
		Set<String> externalProductIds,
		Iterator<OrderItem> iterator,
		List<OrderItem> items
	) {
		List<Product2> existingProducts = [
			SELECT Id,
				external_ID__c
			FROM Product2
			WHERE external_ID__c IN :externalProductIds
			WITH SYSTEM_MODE
		];

		Set<String> existingExternalProductIds = Stream.of(existingProducts).toSet(Product2.external_ID__c);

		iterator = items.iterator();

		while (iterator.hasNext()) {
			OrderItem item = iterator.next();
			externalProductIds.add(item?.Product2?.external_ID__c);

			if (item.Product2 != null && !existingExternalProductIds.contains(item.Product2.external_ID__c)) {
				item.Description__c = item.Description__c ?? item.Product2.external_ID__c;
				item.Product2.external_ID__c = COMMERCE_SETTING.Generic_Product_External_Id__c;
			}
		}
	}

	private static OrderRequest deserializeRequestBody() {
		OrderRequest input = (OrderRequest) JSON.deserializeStrict(
			RestContext.request.requestBody.toString(),
			OrderRequest.class
		);

		return input;
	}

	global class OperationResult {
		global Boolean success { get; set; }
		global String error { get; set; }
		global String orderSummaryId { get; set; }
		global String orderId { get; set; }
		global Map<String, String> orderLineIdByExternalId { get; set; }
	}

	global class OrderRequest {
		global Order orderChange { get; set; }
	}


	private class OrderActivator {
		public Order originalOrder { get; private set; }
		public String postProcessStatus { get; private set; }

		public Boolean isBrandNewExternalOrder {
			get {
				return this.originalOrder == null;
			}
		}

		private OrderRequest input;

		public OrderActivator(OrderRequest input) {
			this.input = input;
			this.originalOrder = fetchOrder(input);
			this.postProcessStatus = Optional.of(input.orderChange.Status, this.originalOrder.Status);
		}

		public OrderActivator(OrderRequest input, Order originalOrder) {
			this.input = input;
			this.originalOrder = originalOrder;
			this.postProcessStatus = Optional.of(input.orderChange.Status, this.originalOrder.Status);
		}

		public void reFetchOrder() {
			this.originalOrder = fetchOrder(input);
		}

		public void populateResultOrderIds(OperationResult result) {
			populateResultOrderIds(result, input.orderChange.OrderItems);
		}

		public void populateResultOrderIds(OperationResult result, List<OrderItem> items) {
			result.orderId = input.orderChange.Id;
			result.orderLineIdByExternalId = new Map<String, String>();

			for (OrderItem item : items) {
				result.orderLineIdByExternalId.put((String) item.get(EXTERNAL_ID_ORDER_ITEM), item.Id);
			}
		}

		private Order fetchOrder(OrderRequest input) {
			return (Order) new Query(Order.SObjectType)
				.selectField(Order.Status)
				.selectField('Account.' + String.valueOf(EXTERNAL_ID_ACCOUNT))
				.addSubquery(Query.subquery('OrderItems')
					.selectField(OrderItem.Id)
					.selectField(OrderItem.Product2Id)
					.selectField(EXTERNAL_ID_ORDER_ITEM)
					.selectField('Product2.' + EXTERNAL_ID_PRODUCT)
				)
				.addSubquery('OrderDeliveryGroups')
				.addConditionEq(EXTERNAL_ID_ORDER, input.orderChange.get(EXTERNAL_ID_ORDER))
				.forUpdate()
				.fetch();
		}

		public void deactivate() {
			this.originalOrder.Status = 'Draft';
			this.input.orderChange.Status = 'Draft';

			update new Order(
				Id = this.originalOrder.Id,
				Status = this.originalOrder.Status
			);
		}

		public void activate() {
			this.originalOrder.Status = this.postProcessStatus;
			update new Order(
				Id = this.originalOrder.Id,
				Status = this.originalOrder.Status
			);
		}

		public void removeOrderSummary() {
			if (this.originalOrder == null) {
				throw new OrderLineChangeException('Order external ID cannot be null');
			}

			delete [
				SELECT Id
				FROM OrderSummary
				WHERE OriginalOrderId = :this.originalOrder.Id
			];
		}

		public String regenerateOrderSummary() {
			ConnectApi.OrderSummaryInputRepresentation orderSummaryInput =
				new ConnectApi.OrderSummaryInputRepresentation();

			orderSummaryInput.orderId = this.originalOrder.Id;
			orderSummaryInput.orderLifeCycleType = 'UNMANAGED';

			return ConnectApi.OrderSummaryCreation.createOrderSummary(orderSummaryInput).orderSummaryId;
		}
	}

	private static SObject stripInaccessibleFieldsForUpdate(SObject record) {
		SObjectType recordSObjectType = record.getSObjectType();
		Map<String, SObjectField> fieldsMap = recordSObjectType.getDescribe().fields.getMap();

		SObject strippedRecord = recordSObjectType.newSObject();

		for (String populatedFieldName : record.getPopulatedFieldsAsMap().keySet()) {
			SObjectField sObjectField = fieldsMap.get(populatedFieldName.toLowerCase());

			if (sObjectField != null && sObjectField.getDescribe().isUpdateable()) {
				strippedRecord.put(populatedFieldName, record.get(populatedFieldName));
			}
		}

		return strippedRecord;
	}

	public class OrderLineChangeException extends Exception {
	}
}