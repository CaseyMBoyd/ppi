/**
 * Sanitizes inbound email HTML before PDF conversion.
 */
public with sharing class HtmlEmailSanitizer {

    public static String sanitizeAndWrap(String rawHtml) {

        String cleanHtml = String.isBlank(rawHtml)
            ? ''
            : rawHtml;

        cleanHtml = removeScriptBlocks(cleanHtml);

        return buildHtmlShell(cleanHtml);
    }


    private static String removeScriptBlocks(String html){

        while(
            html.toLowerCase().contains('<script')
            &&
            html.toLowerCase().contains('</script>')
        ){

            Integer startIndex =
                html.toLowerCase().indexOf('<script');

            Integer endIndex =
                html.toLowerCase().indexOf('</script>') + 9;

            html =
                html.substring(0,startIndex)
                +
                html.substring(endIndex);
        }

        return html;
    }


    private static String buildHtmlShell(String bodyContent) {

        return
        '<!doctype html>' +
        '<html>' +
        '<head>' +
        '<meta charset="utf-8">' +

        '<style>' +

        '@page {' +
        'size: Letter;' +
        'margin:0.5in;' +
        '}' +

        'body {' +
        'font-family:Arial,Helvetica,sans-serif;' +
        'font-size:10pt;' +
        'color:#181818;' +
        '}' +

        'img {' +
        'max-width:100%;' +
        'height:auto;' +
        '}' +

        '</style>' +

        '</head>' +
        '<body>' +

        bodyContent +

        '</body>' +
        '</html>';
    }
}