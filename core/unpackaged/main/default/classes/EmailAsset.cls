/**
 * Wrapper for inbound email inline assets.
 * Purpose:Stores inline images/attachments extracted from email and sends them to Renderer API.
 */
public class EmailAsset {

    public String contentId { get; set; }
    public String fileName { get; set; }
    public String contentType { get; set; }
    public String base64 { get; set; }

    public EmailAsset() {

    }
    public EmailAsset(
        String contentId,
        String fileName,
        String contentType,
        String base64
    ) {
        this.contentId = contentId;
        this.fileName = fileName;
        this.contentType = contentType;
        this.base64 = base64;
    }
}