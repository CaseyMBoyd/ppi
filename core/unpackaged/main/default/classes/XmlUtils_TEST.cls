/**
	* Copyright (c) 2022 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author jakub_cichacki/Forefront
    * @date 13.10.2022
	* @description Test suite

**/

@IsTest
private class XmlUtils_TEST {

    @IsTest
    static void shouldReturnTextFromNode_WhenNotEmpty() {
        //given
        String xmlText = '<Body>\n' +
                '\t<text1>Test1</text1>\n' +
                '\t<text2>Test2</text2>\n' +
                '</Body>';
        Dom.Document doc = new Dom.Document();
        doc.load(xmlText);
        Dom.XmlNode root = doc.getRootElement();

        //when
        String text1 = XmlUtils.getTextFromNode(root, 'text1');
        String text2 = XmlUtils.getTextFromNode(root, 'text2');

        //then
        System.assertEquals('Test1', text1);
        System.assertEquals('Test2', text2);
    }

    @IsTest
    static void shouldReturnEmptyString_WhenNodeEmpty() {
        //given
        String xmlText = '<Body>\n' +
                '\t<text1/>\n' +
                '</Body>';
        Dom.Document doc = new Dom.Document();
        doc.load(xmlText);
        Dom.XmlNode root = doc.getRootElement();

        //when
        String text1 = XmlUtils.getTextFromNode(root, 'text1');

        //then
        System.assertEquals('', text1);
    }

    @IsTest
    static void shouldWriteCharacterElement_whenValueIsNotNull() {
        //given
        System.XmlStreamWriter w = new System.XmlStreamWriter();
        w.writeStartDocument('UTF-8', '1.0');
        w.writeStartElement(null, 'Start', null);

        //when
        XmlUtils.writeCharacterElement(w, 'Value', 'Test', null);

        w.writeEndElement();
        w.writeEndDocument();

        //then
        String xml = w.getXmlString();
        w.close();
        System.assertEquals('Test', xml.substringBetween('<Value>', '</Value>'));
    }

    @IsTest
    static void shouldWriteEmptyXmlTag_whenValueBlank() {
        //given
        System.XmlStreamWriter w = new System.XmlStreamWriter();
        w.writeStartDocument('UTF-8', '1.0');
        w.writeStartElement(null, 'Start', null);

        //when
        XmlUtils.writeCharacterElement(w, 'Value', '', null);

        w.writeEndElement();
        w.writeEndDocument();

        //then
        String xml = w.getXmlString();
        w.close();
        System.assert(xml.contains('<Value/>'));
    }

    @IsTest
    static void shouldWriteObjectElement_WhenLocalNameAndDataNotEmpty() {
        //given
        System.XmlStreamWriter w = new System.XmlStreamWriter();
        w.writeStartDocument('UTF-8', '1.0');
        w.writeStartElement(null, 'Start', null);

        //when
        XmlUtils.writeObjectElement(w, 'Value', new Map<String, String> {
                'testValue' => 'Test'
        }, null);

        w.writeEndDocument();

        //then
        String xml = w.getXmlString();
        w.close();
        System.assertEquals('Test', xml.substringBetween('<testValue>', '</testValue>'));
        System.assert(xml.substringBetween('<Value>', '</Value>').contains('<testValue>'));

    }


}