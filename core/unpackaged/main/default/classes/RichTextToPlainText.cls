/**
 * Converts rich text / HTML strings into plain text for Flow and Process Builder.
 */
public with sharing class RichTextToPlainText {
    private static final String LINE_BREAK_MARKER = '___RICH_TEXT_LINE_BREAK___';

    public class Request {
        @InvocableVariable(required=false label='Rich Text')
        public String richText;
    }

    public class Response {
        @InvocableVariable(label='Plain Text')
        public String plainText;
    }

    @InvocableMethod(
        label='Convert Rich Text to Plain Text'
        description='Removes HTML tags from rich text and returns plain text.'
        category='Text'
    )
    public static List<Response> convert(List<Request> requests) {
        List<Response> responses = new List<Response>();

        if (requests == null) {
            return responses;
        }

        for (Request request : requests) {
            Response response = new Response();
            response.plainText = stripHtml(request?.richText);
            responses.add(response);
        }

        return responses;
    }

    @TestVisible
    private static String stripHtml(String richText) {
        if (richText == null) {
            return null;
        }

        String normalizedRichText = formatListItems(richText)
            .replace('&nbsp;', ' ')
            .replace('&#160;', ' ')
            .replace('&#xA0;', ' ')
            .replaceAll('(?i)</p\\s*>', LINE_BREAK_MARKER)
            .replaceAll('(?i)<br\\s*/?>', LINE_BREAK_MARKER)
            .replaceAll('(?i)</li\\s*>', LINE_BREAK_MARKER)
            .replaceAll('(?i)</ol\\s*>', LINE_BREAK_MARKER)
            .replaceAll('(?i)</ul\\s*>', LINE_BREAK_MARKER);

        return normalizedRichText.stripHtmlTags()
            .unescapeHtml4()
            .replace(LINE_BREAK_MARKER, '\n')
            .replaceAll('[\\t\\x0B\\f\\r ]+', ' ')
            .replaceAll(' *\\n *', '\n')
            .replaceAll('\\n{2,}', '\n')
            .trim();
    }

    private static String formatListItems(String richText) {
        String formattedRichText = formatListItems(richText, 'ol', true);
        return formatListItems(formattedRichText, 'ul', false);
    }

    private static String formatListItems(String richText, String listTagName, Boolean isOrdered) {
        String lowerRichText = richText.toLowerCase();
        String openingTagStart = '<' + listTagName;
        String closingTag = '</' + listTagName + '>';
        Integer searchIndex = 0;
        String formattedRichText = '';

        while (true) {
            Integer listStartIndex = lowerRichText.indexOf(openingTagStart, searchIndex);
            if (listStartIndex == -1) {
                formattedRichText += richText.substring(searchIndex);
                break;
            }

            Integer listOpeningTagEndIndex = lowerRichText.indexOf('>', listStartIndex);
            Integer listEndIndex = lowerRichText.indexOf(closingTag, listOpeningTagEndIndex);
            if (listOpeningTagEndIndex == -1 || listEndIndex == -1) {
                formattedRichText += richText.substring(searchIndex);
                break;
            }

            formattedRichText += richText.substring(searchIndex, listOpeningTagEndIndex + 1);
            formattedRichText += formatItemsInList(richText.substring(listOpeningTagEndIndex + 1, listEndIndex), isOrdered);

            searchIndex = listEndIndex + closingTag.length();
        }

        return formattedRichText;
    }

    private static String formatItemsInList(String listContents, Boolean isOrdered) {
        String lowerListContents = listContents.toLowerCase();
        Integer searchIndex = 0;
        Integer itemNumber = 1;
        String formattedListContents = '';

        while (true) {
            Integer itemStartIndex = lowerListContents.indexOf('<li', searchIndex);
            if (itemStartIndex == -1) {
                formattedListContents += listContents.substring(searchIndex);
                break;
            }

            Integer itemOpeningTagEndIndex = lowerListContents.indexOf('>', itemStartIndex);
            Integer itemEndIndex = lowerListContents.indexOf('</li>', itemOpeningTagEndIndex);
            if (itemOpeningTagEndIndex == -1 || itemEndIndex == -1) {
                formattedListContents += listContents.substring(searchIndex);
                break;
            }

            String itemPrefix = isOrdered ? String.valueOf(itemNumber) + '. ' : '- ';
            formattedListContents += listContents.substring(searchIndex, itemStartIndex);
            formattedListContents += itemPrefix + listContents.substring(itemOpeningTagEndIndex + 1, itemEndIndex) + LINE_BREAK_MARKER;

            itemNumber++;
            searchIndex = itemEndIndex + '</li>'.length();
        }

        return formattedListContents;
    }
}