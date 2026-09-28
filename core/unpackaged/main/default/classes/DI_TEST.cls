/**
 * Copyright (c) 2023 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 09.12.2023 <p/>
 *
 */

@IsTest
private class DI_TEST {

	@IsTest
	static void testDependencyInjection() {
		// given

		List<List<String>> expectedOutput = new List<List<String>>();
		DI.Mock mock = DI.mock(CsvReader.class);
		CsvReader stubbed = (CsvReader) mock.stub;

		mock.startStubbing();
		mock.ignoreArgumentValues(true);
		mock.when(stubbed.getValues()).thenReturn(expectedOutput);
		mock.stopStubbing();

		// when & then
		DummyService service = new DummyService(stubbed);
		Assert.areEqual(expectedOutput, service.parse());
	}

	@IsTest
	static void testDependencyInjection_throwError() {
		// given
		DI.Mock mock = DI.mock(CsvReader.class);
		CsvReader stubbed = (CsvReader) mock.stub;

		mock.startStubbing();
		mock.ignoreArgumentValues(true);
		mock.when(stubbed.getValues()).thenThrow(new NullPointerException());
		mock.stopStubbing();

		DI.inject(CsvReader.class, stubbed);

		Boolean exThrown = false;

		// when
		try {
			new DummyService(stubbed).parse();
		}
		catch(NullPointerException ex) {
			exThrown = true;
		}

		// then
		Assert.isTrue(exThrown);
	}

	private class DummyService {
		private final CsvReader reader;
		public DummyService(CsvReader reader) {
			this.reader = reader;
		}

		public List<List<String>> parse() {
			return this.reader.getValues();
		}
	}
}