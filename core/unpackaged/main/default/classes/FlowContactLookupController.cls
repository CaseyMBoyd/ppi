/**
 * @description Apex controller for the flowContactLookup LWC. Returns contacts
 *              related to a given Account through AccountContactRelation records.
 */
public with sharing class FlowContactLookupController {

    private static final Integer MAX_RESULTS = 25;

    public class ContactOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String email;

        public ContactOption(Id id, String name, String title, String email) {
            this.id = id;
            this.name = name;
            this.title = title;
            this.email = email;
        }
    }

    /**
     * @description Search contacts related to an account via AccountContactRelation.
     *              Direct (primary) relationships and indirect relationships are both included.
     * @param accountId  The Account whose related contacts should be returned.
     * @param searchTerm Optional name fragment; when blank, the most recent relations are returned.
     * @return A list of contact options, capped at MAX_RESULTS.
     */
    @AuraEnabled(cacheable=true)
    public static List<ContactOption> searchRelatedContacts(Id accountId, String searchTerm) {
        if (accountId == null) {
            return new List<ContactOption>();
        }

        String term = (searchTerm == null) ? '' : searchTerm.trim();
        Boolean hasTerm = String.isNotBlank(term);
        String likeTerm = '%' + String.escapeSingleQuotes(term) + '%';

        List<AccountContactRelation> relations;
        if (hasTerm) {
            relations = [
                SELECT ContactId, Contact.Name, Contact.Title, Contact.Email
                FROM AccountContactRelation
                WHERE AccountId = :accountId
                  AND IsActive = TRUE
                  AND Contact.Name LIKE :likeTerm
                ORDER BY Contact.Name ASC
                LIMIT :MAX_RESULTS
            ];
        } else {
            relations = [
                SELECT ContactId, Contact.Name, Contact.Title, Contact.Email
                FROM AccountContactRelation
                WHERE AccountId = :accountId
                  AND IsActive = TRUE
                ORDER BY Contact.Name ASC
                LIMIT :MAX_RESULTS
            ];
        }

        Map<Id, ContactOption> deduped = new Map<Id, ContactOption>();
        for (AccountContactRelation rel : relations) {
            if (rel.ContactId == null || deduped.containsKey(rel.ContactId)) {
                continue;
            }
            deduped.put(
                rel.ContactId,
                new ContactOption(
                    rel.ContactId,
                    rel.Contact.Name,
                    rel.Contact.Title,
                    rel.Contact.Email
                )
            );
        }
        return deduped.values();
    }

    /**
     * @description Fetches a single contact by Id. Used to hydrate the lookup when the
     *              flow pre-populates a selectedContactId on entry.
     */
    @AuraEnabled(cacheable=true)
    public static ContactOption getContactById(Id contactId) {
        if (contactId == null) {
            return null;
        }
        List<Contact> contacts = [
            SELECT Id, Name, Title, Email
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        if (contacts.isEmpty()) {
            return null;
        }
        Contact c = contacts[0];
        return new ContactOption(c.Id, c.Name, c.Title, c.Email);
    }
}