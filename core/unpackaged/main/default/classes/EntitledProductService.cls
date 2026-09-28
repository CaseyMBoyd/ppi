/**
	* Copyright (c) 2021 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author Forefront
	* @version 1.0
	* @description
	*
	* PURPOSE
	*
	*   Fetches entitled products for a B2B Commerce User
	*
	* TEST CLASS
	*
	*   EntitledProductService_TEST
	*
	* CHANGE LOG
	*
	*    [Version; Date; Author; Description]
	*    v1.0; 10/11/2021; Forefront; Initial Build
	*
**/

public without sharing class EntitledProductService {

    private static EntitledProductService instance;

    public static EntitledProductService getInstance() {
        if (instance == null) {
            instance = (EntitledProductService) ServiceFactory.get(
                    EntitledProductService.class
            );
        }
        return instance;
    }

    public BuyerRecords fetchBuyerRecords(Id webstoreId, Id effectiveAccountId) {
        BuyerRecords records = new BuyerRecords();

        records.webStore = [SELECT Id, PricingStrategy FROM WebStore WHERE Id =: webstoreId];
        records.members = fetchBuyerGroupMembers(webstoreId, effectiveAccountId);
        records.pricebooks = fetchBuyerGroupPricebooks(records.groupIds);
        records.policies = fetchBuyerGroupPolicies(records.groupIds);

        return records;
    }

    public List<BuyerGroupPricebook> fetchBuyerGroupPricebooks(Set<Id> buyerGroupIDs) {
        return [
                SELECT Id,
                        Pricebook2Id,
                        Priority,
                        Pricebook2.Name,
                        Pricebook2.ValidTo,
                        Pricebook2.ValidFrom
                FROM BuyerGroupPricebook
                WHERE BuyerGroupId IN: buyerGroupIDs
                AND IsActive = TRUE
                AND Pricebook2.IsActive = TRUE
                ORDER BY Priority DESC
        ];
    }

    public List<CommerceEntitlementBuyerGroup> fetchBuyerGroupPolicies(Set<Id> buyerGroupIDs) {
        return [
                SELECT Id,
                        PolicyId
                FROM CommerceEntitlementBuyerGroup
                WHERE BuyerGroupId IN:buyerGroupIDs
        ];
    }

    public List<BuyerGroupMember> fetchBuyerGroupMembers(Id webstoreId, Id effectiveAccountId) {
        return [
                SELECT Id,
                        BuyerGroupId
                FROM BuyerGroupMember
                WHERE BuyerId = :effectiveAccountId
                AND BuyerGroupId IN (
                        SELECT BuyerGroupId
                        FROM WebStoreBuyerGroup
                        WHERE WebStoreId = :webstoreId
                )
        ];
    }

    public class BuyerRecords {

        public WebStore webStore { get; set; }
        public List<BuyerGroupMember> members { get; set; }
        public List<BuyerGroupPricebook> pricebooks { get; set; }
        public List<CommerceEntitlementBuyerGroup> policies { get; set; }

        public String pricingStrategy {
            get {
                return webStore?.PricingStrategy;
            }
        }

        public Set<Id> groupIds {
            get {
                if (groupIds == null) {
                    groupIds = Stream.of(members).toSetOfIds(BuyerGroupMember.BuyerGroupId);
                }
                return groupIds;
            }
            private set;
        }

        public Set<Id> policyIds {
            get {
                if (policyIds == null) {
                    policyIds = Stream.of(policies).toSetOfIds(CommerceEntitlementBuyerGroup.PolicyId);
                }
                return policyIds;
            }
            private set;
        }

        public Set<Id> pricebookIds {
            get {
                if (pricebookIds == null) {
                    pricebookIds = Stream.of(pricebooks).toSetOfIds(BuyerGroupPricebook.Pricebook2Id);
                }
                return pricebookIds;
            }
            private set;
        }

    }

}