public without sharing class xStudio_EmailToLeadOIC implements Messaging.InboundEmailHandler {
  public Messaging.InboundEmailResult handleInboundEmail(
    Messaging.inboundEmail email,
    Messaging.InboundEnvelope env
  ) {
    Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

    List<EmailMessage> existingEmailMessages = new List<EmailMessage>();
    if (email.references != null) {
      existingEmailMessages = xStudio_EmailToLeadUtility.getExistingEmailMessages(
        email.references
      );
    }

    if (existingEmailMessages.size() > 0) {
      xStudio_EmailToLeadUtility.linkToExistingEmailMessages(
        existingEmailMessages,
        email
      );
    } else {
      xStudio_EmailToLeadUtility.createLead(email, 'OIC Queue');
    }

    result.success = true;
    return result;
  }
}