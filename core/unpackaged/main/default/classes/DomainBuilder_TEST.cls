@IsTest
public class DomainBuilder_TEST {

	@IsTest
	private static void noUnneededRecords() {

		// Setup & Exercise
		Contact_t con = new Contact_t();            // 1x insert
		Opportunity_t opp = new Opportunity_t();    // 1x insert

		new Account_t()                             // 1x insert
			.add(new Contact_t())               // 1x insert
			.add(con)                           // 0x insert
			.add(opp                            // 0x insert
				.add(con))                     // 1x insert OpportunityContactRole
			.persist();                         // 1x setSavepoint

		// Verify
		System.assertEquals(6, Limits.getDmlRows());
		System.assertEquals(1, [SELECT Count() FROM Account]);
		System.assertEquals(2, [SELECT Count() FROM Contact]);
		System.assertEquals(1, [SELECT Count() FROM Opportunity]);
		System.assertEquals(1, [SELECT Count() FROM OpportunityContactRole]);
	}


	@IsTest
	private static void recordTypeSetting() {

		try {
			Contact_t con = (Contact_t) new Contact_t().recordType('TEST');
		}
		catch(Exception ex){

		}
	}

	@IsTest
	private static void happyPath() {

		Contact_t ron = new Contact_t().first('Ron').last('Harris');

		new Account_t()
			.name('Acme Corp')
			.add(new Contact_t())
			.add(new Opportunity_t()
				.amount(1000)
				.closes(2019, 12)
				.contact(ron))
			.persist();

		System.assertEquals(2, [SELECT Count() FROM Account]); // TODO: Should be 1 actually.
		System.assertEquals(1, [SELECT Count() FROM Opportunity]);
		System.assertEquals(2, [SELECT Count() FROM Contact]);
		System.assertEquals(1, [SELECT Count() FROM OpportunityContactRole]);
	}


	@IsTest
	private static void autoPopulatesRequiredButIrrelevantFields() {

		new Account_t()
			.add(new Contact_t())
			.add(new Opportunity_t())

			.persist();

		System.assertNotEquals(null, [SELECT Name FROM Account]);
		System.assertNotEquals(null, [SELECT LastName FROM Contact]);
		System.assertNotEquals(null, [SELECT StageName FROM Opportunity]);
	}


	@IsTest
	private static void autoGeneratesRequiredButIrrelevantRelations() {

		new Opportunity_t()
			.amount(1000)

			.persist();

		System.assertEquals(1, [SELECT Count() FROM Account]);
		System.assertEquals(1, [SELECT Count() FROM Opportunity]);
		System.assertNotEquals(null, [SELECT AccountId FROM Opportunity]);
	}


	@IsTest
	private static void allowNicerFieldSetters() {

		new Opportunity_t()
			.closes(2019, 7)
			.persist();

		System.assertEquals(Date.newInstance(2019, 7, 1), [SELECT CloseDate FROM Opportunity].CloseDate);
	}


	@IsTest
	private static void addChildrenOfArbitraryDepth() {

		new Account_t()
			.add(new Contact_t())
			.add(new Contact_t())

			.add(new Opportunity_t())
			.add(new Opportunity_t())

			.persist();

		System.assertEquals(1, [SELECT Count() FROM Account]);
		System.assertEquals(2, [SELECT Count() FROM Opportunity]);
		System.assertEquals(2, [SELECT Count() FROM Contact]);
	}


	@IsTest
	private static void allowsSetupObjects() {

		try {
			System.runAs(standard()) {
				new Account_t().persist();
			}
		}
		catch (Exception ex) {
			System.assert(false);
		}

		System.assertEquals(1, [SELECT Count() FROM Account]);
	}


	@IsTest
	private static void allowsSelfReferences() {

		// Setup & Exercise
		Contact_t boss = new Contact_t();
		new Contact_t()
			.reports(boss)
			.persist();

		// Verify
		System.assertEquals(2, [SELECT Count() FROM Contact]);
		System.assertEquals(1, [SELECT Count() FROM Contact WHERE ReportsToId != NULL]);
	}


	@IsTest
	private static void allowsJunctionObjects() {

		Opportunity_t o = new Opportunity_t();
		Contact_t c = new Contact_t();
		new OpportunityContactRole_t(o, c).persist();

		System.assertEquals(1, [
			SELECT Count()
			FROM OpportunityContactRole
			WHERE ContactId = :c.Id AND OpportunityId = :o.Id
		]);
	}


	@IsTest
	private static void hideLinkerComplexity() {

		new Opportunity_t()
			.contact(new Contact_t())
			.persist();

		System.assertEquals(1, [
			SELECT Count()
			FROM OpportunityContactRole
			WHERE ContactId != null AND OpportunityId != null
		]);
	}


	@IsTest
	private static void accessRecordFromBuilder() {

		Account_t a = new Account_t().name('Salesforce.com');
		a.persist();

		System.assertEquals(Account.SObjectType, a.record.getSObjectType());
	}


	@IsTest
	private static void accessIdFromBuilder() {
		Account_t a = new Account_t();
		a.persist();

		System.assertEquals(a.Id, [SELECT Id FROM Account].Id);
	}


	@IsTest
	private static void insertOrder() {

		// Setup
		DomainBuilder.DirectedGraph graph = new DomainBuilder.DirectedGraph()
			.node(Account.SObjectType)
			.node(Contact.SObjectType)
			.node(Opportunity.SObjectType)
			.node(OpportunityContactRole.SObjectType)

			.edge(Contact.SObjectType, Account.SObjectType)
			.edge(Contact.SObjectType, Opportunity.SObjectType)
			.edge(Opportunity.SObjectType, Account.SObjectType)
			.edge(OpportunityContactRole.SObjectType, Contact.SObjectType)
			.edge(OpportunityContactRole.SObjectType, Opportunity.SObjectType);

		// Verify
		List<SObjectType> expectedOrder = new List<SObjectType>{
			OpportunityContactRole.SObjectType, Contact.SObjectType, Opportunity.SObjectType, Account.SObjectType
		};
		System.assertEquals(expectedOrder, graph.sortTopologically());
	}

	public class Account_t extends DomainBuilder {

		public Account_t() {
			super(Account.SObjectType);

			name('Acme Corp');
		}

		public Account_t name(String value) {
			return (Account_t) set(Account.Name, value);
		}


		public Account_t add(Contact_t c) {
			return (Account_t) c.setParent(Contact.AccountId, this);
		}

		public Account_t add(Opportunity_t o) {
			return (Account_t) o.setParent(Opportunity.AccountId, this);
		}
	}

	public class Contact_t extends DomainBuilder {

		public Contact_t(Account_t a) {
			super(Contact.SObjectType);
			setParent(Contact.AccountId, a);

			last('test');
		}

		public Contact_t() {
			this(new Account_t());
		}

		public Contact_t first(String value) {
			return (Contact_t) set(Contact.FirstName, value);
		}

		public Contact_t last(String value) {
			return (Contact_t) set(Contact.LastName, value);
		}

		public Contact_t email(String value) {
			return (Contact_t) set(Contact.Email, value);
		}

		public Contact_t reports(Contact_t c) {
			return (Contact_t) setParent(Contact.ReportsToId, c);
		}
	}
	public class Opportunity_t extends DomainBuilder {

		public Opportunity_t(Account_t a) {
			super(Opportunity.SObjectType);
			setParent(Opportunity.AccountId, a);

			name('Opp1');
			stage('Open');
			closes(System.today().year() + 1, 1);
		}

		public Opportunity_t() {
			this(new Account_t());
		}

		public Opportunity_t name(String value) {
			return (Opportunity_t) set(Opportunity.Name, value);
		}

		public Opportunity_t amount(Decimal value) {
			return (Opportunity_t) set(Opportunity.Amount, value);
		}

		public Opportunity_t stage(String value) {
			return (Opportunity_t) set(Opportunity.StageName, value);
		}

		public Opportunity_t contact(Contact_t c) {
			new OpportunityContactRole_t(this, c);
			return this;
		}

		public Opportunity_t closes(Integer y, Integer m) {
			return (Opportunity_t) set(Opportunity.CloseDate, Date.newInstance(y, m, 1));
		}

		public Opportunity_t add(Contact_t c) {
			new OpportunityContactRole_t(this, c);
			return this;
		}
	}

	public class OpportunityContactRole_t extends DomainBuilder {

		public OpportunityContactRole_t(Opportunity_t o, Contact_t c) {
			super(OpportunityContactRole.SObjectType);
			setParent(OpportunityContactRole.OpportunityId, o);
			setParent(OpportunityContactRole.ContactId, c);
		}

		public OpportunityContactRole_t(Contact_t c) {
			this(new Opportunity_t(), c);
		}
	}
	private final static Id STANDARD_USER = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id;
	private static User standard() {
		return (User) new User_t()
			.set(User.profileId, STANDARD_USER)
			.persist();
	}
	public with sharing class User_t extends DomainBuilder {


		public User_t() {
			super(User.SObjectType);

			String name = 'test_user';
			set(User.Alias, 'alias');
			set(User.Email, name + '@scott.com');
			set(User.EmailEncodingKey, 'UTF-8');
			set(User.FirstName, 'Jill');
			set(User.Lastname, 'Scott');
			set(User.languagelocalekey, 'en_US');
			set(User.localesidkey, 'en_US');
			set(User.timezonesidkey, 'America/Los_Angeles');
			set(User.isActive, true);
			set(User.username, name + '@scott.com');
			set(User.profileId, STANDARD_USER);
			set(User.UserPermissionsSFContentUser, false);
		}
	}
}