@IsTest
private class RichTextToPlainText_TEST {
    @IsTest
    static void convertRemovesHtmlAndDecodesEntities() {
        List<RichTextToPlainText.Request> requests = new List<RichTextToPlainText.Request>{
            newRequest('<p>Hello <strong>Sales</strong> &amp; Ops</p><br><div>Ready&nbsp;now</div>')
        };

        Test.startTest();
        List<RichTextToPlainText.Response> responses = RichTextToPlainText.convert(requests);
        Test.stopTest();

        Assert.areEqual(1, responses.size(), 'One response should be returned for one request.');
        Assert.areEqual('Hello Sales & Ops\nReady now', responses[0].plainText, 'HTML tags should be stripped and entities decoded.');
    }

    @IsTest
    static void convertRetainsParagraphAndListLineBreaks() {
        List<RichTextToPlainText.Request> requests = new List<RichTextToPlainText.Request>{
            newRequest('<p>First paragraph</p><p>Second paragraph</p><ol><li>Ordered one</li><li>Ordered two</li></ol><ul><li>Bullet one</li><li>Bullet two</li></ul>')
        };

        List<RichTextToPlainText.Response> responses = RichTextToPlainText.convert(requests);

        Assert.areEqual(
            'First paragraph\nSecond paragraph\n1. Ordered one\n2. Ordered two\n- Bullet one\n- Bullet two',
            responses[0].plainText,
            'Paragraphs and list items should remain on separate lines with list markers.'
        );
    }

    @IsTest
    static void convertFormatsListItemsWithInlineMarkup() {
        List<RichTextToPlainText.Request> requests = new List<RichTextToPlainText.Request>{
            newRequest('<ul><li><strong>Important</strong> item</li></ul><ol><li>Step &amp; go</li></ol>')
        };

        List<RichTextToPlainText.Response> responses = RichTextToPlainText.convert(requests);

        Assert.areEqual(
            '- Important item\n1. Step & go',
            responses[0].plainText,
            'List markers should be retained while inline markup is stripped.'
        );
    }

    @IsTest
    static void convertHandlesNullAndBlankValues() {
        List<RichTextToPlainText.Request> requests = new List<RichTextToPlainText.Request>{
            newRequest(null),
            newRequest(''),
            null
        };

        List<RichTextToPlainText.Response> responses = RichTextToPlainText.convert(requests);

        Assert.areEqual(3, responses.size(), 'Responses should preserve request cardinality.');
        Assert.isNull(responses[0].plainText, 'Null rich text should remain null.');
        Assert.areEqual('', responses[1].plainText, 'Blank rich text should remain blank.');
        Assert.isNull(responses[2].plainText, 'Null request entries should return a null plain text value.');
    }

    @IsTest
    static void convertHandlesBulkRequestsInOrder() {
        List<RichTextToPlainText.Request> requests = new List<RichTextToPlainText.Request>();
        for (Integer index = 0; index < 251; index++) {
            requests.add(newRequest('<span>Item ' + index + '</span>'));
        }

        List<RichTextToPlainText.Response> responses = RichTextToPlainText.convert(requests);

        Assert.areEqual(251, responses.size(), 'Bulk requests should return one response per request.');
        Assert.areEqual('Item 0', responses[0].plainText, 'First response should match the first request.');
        Assert.areEqual('Item 250', responses[250].plainText, 'Last response should match the last request.');
    }

    @IsTest
    static void convertHandlesNullRequestList() {
        List<RichTextToPlainText.Response> responses = RichTextToPlainText.convert(null);

        Assert.areEqual(0, responses.size(), 'Null request lists should return an empty response list.');
    }

    private static RichTextToPlainText.Request newRequest(String richText) {
        RichTextToPlainText.Request request = new RichTextToPlainText.Request();
        request.richText = richText;
        return request;
    }
}