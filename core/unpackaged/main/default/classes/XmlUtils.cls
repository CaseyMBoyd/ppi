/**
	* Copyright (c) 2022 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author jakub_cichacki/Forefront
	* @date 13.10.2022 <p/>
	* @description
	* @test XmlUtils_TEST
**/
global class XmlUtils {
    global static String getTextFromNode(Dom.XmlNode parent, String nodeName) {
        return parent.getChildElement(nodeName, parent.getNamespace()).getText().trim();
    }

    global static void writeCharacterElement(
            System.XmlStreamWriter writer,
            String localName,
            String value,
            String namespaceURI
    ) {
        if (String.isBlank(value)) {
            writer.writeEmptyElement(null, localName, namespaceURI);
        }
        else {
            writer.writeStartElement(null, localName, namespaceURI);
            writer.writeCharacters(value);
            writer.writeEndElement();
        }
    }

    global static void writeObjectElement(
            System.XmlStreamWriter writer,
            String localName,
            Map<String, String> data,
            String namespaceURI
    ) {
        writer.writeStartElement(null, localName, namespaceURI);
        for (String key : data.keySet()) {
            writeCharacterElement(writer, key, data.get(key), namespaceURI);
        }
        writer.writeEndElement();
    }

}