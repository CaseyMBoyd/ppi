/**
	* Copyright (c) 2017 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author tdennis/Forefront
	* @version 1.0
	* @description Test class for CsvReader
**/
@IsTest
private class CsvReader_TEST {

	@IsTest
	private static void locationSpecialCharsTest() {
		String csvString = 'aaa,bbb,ccc,ddd\n' +
			'eee,fff,ggg,hhh\n';
		CsvReader reader = new CsvReader(csvString);
		reader.calculateSpecialCharactersPositions();
		System.assertEquals(3, reader.commaPosition);
		System.assertEquals(15, reader.nlPosition);
	}

	@IsTest
	private static void locationSpecialCharsInitialPositionTest() {
		String csvString = 'aaa,bbb,ccc,ddd\n' +
			'eee,fff,ggg,hhh\n';
		CsvReader reader = new CsvReader(csvString);
		reader.position = 10;
		reader.calculateSpecialCharactersPositions();
		System.assertEquals(11, reader.commaPosition);
		System.assertEquals(15, reader.nlPosition);
	}

	@IsTest
	private static void parseCSVwithoutQuotes() {
		String csvString = 'aaa,bbb,ccc,ddd\n' +
			'eee,fff,ggg,hhh\n';
		List < List < String >> outputMatrix = CsvReader.parse(csvString);
		System.assertEquals(2, outputMatrix.size());
		System.assertEquals(4, outputMatrix.get(0).size());
		System.assertEquals(4, outputMatrix.get(1).size());
		System.assertEquals('aaa', outputMatrix.get(0).get(0));
		System.assertEquals('bbb', outputMatrix.get(0).get(1));
		System.assertEquals('ccc', outputMatrix.get(0).get(2));
		System.assertEquals('ddd', outputMatrix.get(0).get(3));
		System.assertEquals('eee', outputMatrix.get(1).get(0));
		System.assertEquals('fff', outputMatrix.get(1).get(1));
		System.assertEquals('ggg', outputMatrix.get(1).get(2));
		System.assertEquals('hhh', outputMatrix.get(1).get(3));
	}

	@IsTest
	private static void parseCSVoneWithQoute() {
		String csvString = 'aaa,"bbb",ccc,ddd\n' +
			'eee,fff,ggg,hhh\n';
		List < List < String >> outputMatrix = CsvReader.parse(csvString);
		System.assertEquals(2, outputMatrix.size());
		System.assertEquals(4, outputMatrix.get(0).size());
		System.assertEquals(4, outputMatrix.get(1).size());
		System.assertEquals('aaa', outputMatrix.get(0).get(0));
		System.assertEquals('bbb', outputMatrix.get(0).get(1));
		System.assertEquals('ccc', outputMatrix.get(0).get(2));
		System.assertEquals('ddd', outputMatrix.get(0).get(3));
		System.assertEquals('eee', outputMatrix.get(1).get(0));
		System.assertEquals('fff', outputMatrix.get(1).get(1));
		System.assertEquals('ggg', outputMatrix.get(1).get(2));
		System.assertEquals('hhh', outputMatrix.get(1).get(3));
	}

	@IsTest
	private static void parseCSVlastOneWithQoute() {
		String csvString = 'aaa,bbb,ccc,"ddd"\n' +
			'eee,fff,ggg,hhh\n';
		List < List < String >> outputMatrix = CsvReader.parse(csvString);
		System.assertEquals(2, outputMatrix.size());
		System.assertEquals(4, outputMatrix.get(0).size());
		System.assertEquals(4, outputMatrix.get(1).size());
		System.assertEquals('aaa', outputMatrix.get(0).get(0));
		System.assertEquals('bbb', outputMatrix.get(0).get(1));
		System.assertEquals('ccc', outputMatrix.get(0).get(2));
		System.assertEquals('ddd', outputMatrix.get(0).get(3));
		System.assertEquals('eee', outputMatrix.get(1).get(0));
		System.assertEquals('fff', outputMatrix.get(1).get(1));
		System.assertEquals('ggg', outputMatrix.get(1).get(2));
		System.assertEquals('hhh', outputMatrix.get(1).get(3));
	}

	@IsTest
	private static void parseCSVescapeLineBreak() {
		String csvString = 'aaa,"bb\nb",ccc,"ddd"\n' +
			'eee,fff,ggg,hhh\n';
		List < List < String >> outputMatrix = CsvReader.parse(csvString);
		System.assertEquals(2, outputMatrix.size());
		System.assertEquals(4, outputMatrix.get(0).size());
		System.assertEquals(4, outputMatrix.get(1).size());
		System.assertEquals('aaa', outputMatrix.get(0).get(0));
		System.assertEquals('bb\nb', outputMatrix.get(0).get(1));
		System.assertEquals('ccc', outputMatrix.get(0).get(2));
		System.assertEquals('ddd', outputMatrix.get(0).get(3));
		System.assertEquals('eee', outputMatrix.get(1).get(0));
		System.assertEquals('fff', outputMatrix.get(1).get(1));
		System.assertEquals('ggg', outputMatrix.get(1).get(2));
		System.assertEquals('hhh', outputMatrix.get(1).get(3));
	}

	@IsTest
	private static void parseCSVescapeQouteSymbol() {
		String csvString = 'aaa,"""bbb","""ccc""","ddd"""\n' +
			'eee,fff,ggg,hhh\n';
		List < List < String >> outputMatrix = CsvReader.parse(csvString);
		System.assertEquals(2, outputMatrix.size());
		System.assertEquals(4, outputMatrix.get(0).size());
		System.assertEquals(4, outputMatrix.get(1).size());
		System.assertEquals('aaa', outputMatrix.get(0).get(0));
		System.assertEquals('"bbb', outputMatrix.get(0).get(1));
		System.assertEquals('"ccc"', outputMatrix.get(0).get(2));
		System.assertEquals('ddd"', outputMatrix.get(0).get(3));
		System.assertEquals('eee', outputMatrix.get(1).get(0));
		System.assertEquals('fff', outputMatrix.get(1).get(1));
		System.assertEquals('ggg', outputMatrix.get(1).get(2));
		System.assertEquals('hhh', outputMatrix.get(1).get(3));
	}

	@IsTest
	private static void parseCSVwhite() {
		String csvString = 'aaa, bbb ,ccc,ddd\n' +
			'eee,fff,ggg,hhh\n';
		List < List < String >> outputMatrix = CsvReader.parse(csvString);
		System.assertEquals(2, outputMatrix.size());
		System.assertEquals(4, outputMatrix.get(0).size());
		System.assertEquals(4, outputMatrix.get(1).size());
		System.assertEquals('aaa', outputMatrix.get(0).get(0));
		System.assertEquals(' bbb ', outputMatrix.get(0).get(1));
		System.assertEquals('ccc', outputMatrix.get(0).get(2));
		System.assertEquals('ddd', outputMatrix.get(0).get(3));
		System.assertEquals('eee', outputMatrix.get(1).get(0));
		System.assertEquals('fff', outputMatrix.get(1).get(1));
		System.assertEquals('ggg', outputMatrix.get(1).get(2));
		System.assertEquals('hhh', outputMatrix.get(1).get(3));
	}
}