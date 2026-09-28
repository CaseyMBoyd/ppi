/**
	* Copyright (c) 2022 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author Mateusz Kieczkowski/Forefront
	* @version 1.0
	* @description
	*
	* PURPOSE
	* 
	*
	* 
	* TEST CLASS 
	* 
	* 
	*  
	* ENTRY POINTS 
	*  
	*    
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 14.10.2022; Mateusz Kieczkowski/Forefront; Initial Build
	* 
**/
public with sharing class CsvReader {
    public static List<List<String>> parseBase64(String base64) {
        return parse(EncodingUtil.base64Decode(base64).toString());
    }

    /**
     * @description entry point of CSV parser.
     * @param csvString content of csv stored in string object
     * @return output CSV data stored in two dimensional list.
     */
    public static List<List<String>> parse(String csvString) {
        try {
            CsvReader reader = new CsvReader(csvString);
            return reader.getValues();
        }
        catch(Exception ex){
            throw new MalformedCsvException(ex);
        }
    }

    /*
     * @description field stores content of csv file
     */
    private String csvString;
    /**
     * @description field defines internal state of parser.
     */
    @testVisible
    private Integer position = 0;
    /**
     * @description fields defines length of content of csv file
     */
    private Integer csvStringLength;
    /**
     * @description field defines current state of CSV parser: escaping enabled or not.
     */
    private boolean escape = false;
    /**
     * @description stores position of colssest comma
     */
    @testVisible
    private Integer commaPosition;
    /**
     * @description stores position of closest line break
     */
    @testVisible
    private Integer nlPosition;
    /**
     * @description stores position of closest quote position
     */
    @testVisible
    private Integer quotePosition;
    /**
     * @descrption stores position of closest double qoute
     */
    @testVisible
    private Integer doubleQuotePosition;
    /**
     * @description special character which separaates column values
     */
    private static String COMMA = ',';
    /**
     * @description special character which separates rows
     */
    private static String NL = '\n';
    /**
     * @description special character which is used to store special characters inside values
     */
    private static String QUOTE = '"';
    /**
     * @description special character which is used for escape qoute symbol inside value
     */
    private static String DOUBLE_QUOTE = '""';

    /**
     * @description construcrot which set initial state of parser engine
     * @param csvString content of csv stored in string object
     */
    public CsvReader(String csvString) {
        this.csvString = ensureCorrectCsvEnding(csvString);
        this.csvStringLength = this.csvString.length();
    }

    @TestVisible
    private CsvReader() { }

    private String ensureCorrectCsvEnding(String csvString) {
        csvString = (String.isNotBlank(csvString) ? csvString :  '').trim();
        csvString = csvString.right(1) == ',' ? csvString.removeEnd(',') : csvString;
        csvString = csvString.contains('\r\n') ? csvString.replaceAll('\r\n', '\n') : csvString;
        csvString = csvString.right(1) == '\n' ? csvString : csvString + '\n';
        return csvString;
    }

    /**
     * @description internal function used by each iteration of special character in CSV file for retreive location of
     * each closest special characters
     */
    @TestVisible
    private void calculateSpecialCharactersPositions() {
        this.commaPosition = this.csvString.indexOf(COMMA, this.position);
        this.nlPosition = this.csvString.indexOf(NL, this.position);
        this.quotePosition = this.csvString.indexOf(QUOTE, this.position);
        this.doubleQuotePosition = this.csvString.indexOf(DOUBLE_QUOTE, this.position);
    }

    /**
     * @description internal function used to spot of closest special character from current buffer position
     * @return one of the special characters it could be: comma, qoute, double qoute or line break. In case not
     * special characted found then null will be returned
     */
    @TestVisible
    private String closestSpecialCharacter() {
        List<Integer> allPositions = new List<Integer>{
            this.commaPosition, this.nlPosition, this.quotePosition, this.doubleQuotePosition
        };
        List<Integer> positions = new List<Integer>();
        for (Integer position : allPositions) {
            if (position != -1) {
                positions.add(position);
            }
        }
        positions.sort();
        if (positions.isEmpty()) {
            return null;
        }
        else {
            Integer colsestSignPosition = positions.get(0);
            if (colsestSignPosition == commaPosition) {
                return COMMA;
            }
            else if (colsestSignPosition == nlPosition) {
                return NL;
            }
            else if (colsestSignPosition == quotePosition) {
                if (!escape) {
                    return QUOTE;
                }
                else if (csvString.substring(quotePosition + 1, quotePosition + 2).equals('"')) {
                    return DOUBLE_QUOTE;
                }
                else {
                    return QUOTE;
                }
            }
            else {
                return DOUBLE_QUOTE;
            }
        }
    }

    /**
     * @description main function of CSV parser. Method is implemented by iteration throught special characters, content
     * stored between special characters are stored as a values in output lists.
     * @return CSV data
     */
    public List<List<String>> getValues() {
        List<List<String>> lines = new List<List<String>>();
        List<String> row = new List<String>();
        Integer columnValueStartPosition = 0;
        while (position < csvStringLength) {
            calculateSpecialCharactersPositions();
            String closestChar = closestSpecialCharacter();
            if (COMMA.equals(closestChar)) {
                position = commaPosition + COMMA.length();
                if (!escape) {
                    String value = csvString.substring(columnValueStartPosition, commaPosition);

                    columnValueStartPosition = position;
                    row.add(value);
                }
            }
            else if (NL.equals(closestChar)) {
                position = nlPosition + NL.length();
                if (!escape) {
                    String value = csvString.substring(columnValueStartPosition, nlPosition);

                    columnValueStartPosition = position;
                    row.add(value);
                    lines.add(row);
                    row = new List<String>();
                }
            }
            else if (QUOTE.equals(closestChar)) {
                escape = !escape;
                if (escape) {
                    position = quotePosition + QUOTE.length();
                    columnValueStartPosition = position;
                }
                else {
                    String value = csvString.substring(columnValueStartPosition, quotePosition);
                    if (value.contains(DOUBLE_QUOTE)) {
                        value = value.replace(DOUBLE_QUOTE, QUOTE);
                    }
                    position = quotePosition + (QUOTE + COMMA).length();
                    columnValueStartPosition = position;
                    row.add(value);
                    String nextChar = CsvReader.charAt(csvString, quotePosition + QUOTE.length());
                    if (nextChar.equals(NL)) {
                        lines.add(row);
                        row = new List<String>();
                    }
                }
            }
            else {
                position = quotePosition + DOUBLE_QUOTE.length();
            }
        }
        return lines;

    }

    /**
     * @description function is used to get char from source string based on position
     * @param postion index of char
     * @return concrete char stored at given postion
     */
    private static String charAt(String source, Integer position) {
        return source.substring(position, position + 1);
    }

    public class MalformedCsvException extends Exception {}
}