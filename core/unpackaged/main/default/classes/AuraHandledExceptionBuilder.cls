/**
 * Copyright (c) 2021 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author tomdennis/Forefront
 * @version 1.0
 * @description
 *
 * PURPOSE
 *
 *   Controller for AuraHandledExceptionBuilder
 *
 * TEST CLASS
 *
 *    AuraHandledExceptionBuilder_TEST
 *
 * CHANGE LOG
 *
 *    [Version; Date; Author; Description]
 *    v1.0; 2/17/21; tomdennis/Forefront; Initial Build
 *
 **/

//Aura Exception only accepts data type of string,
//must be parsed on front to handle as an object
global with sharing class AuraHandledExceptionBuilder {
    private ExceptionMessage auraExceptionMessage;

    global class ExceptionMessage {
        @AuraEnabled
        public String serverMessage { get; set; }
    }

    global static ExceptionMessage buildMessage(Exception ex) {
        return new AuraHandledExceptionBuilder().executeDebugLog(ex).withMessage(formatExceptionMessage(ex)).build();
    }

    global static String buildClientMessage(Exception ex) {
        ExceptionMessage message = buildMessage(ex);
        return JSON.serialize(message);
    }

    global AuraHandledExceptionBuilder() {
        this.auraExceptionMessage = new ExceptionMessage();
    }

    global AuraHandledExceptionBuilder withMessage(String message) {
        this.auraExceptionMessage.serverMessage = message;
        return this;
    }

    global AuraHandledExceptionBuilder executeDebugLog(Exception ex) {
        System.debug(LoggingLevel.ERROR, 'Aura Handled Exception: ');
        System.debug(LoggingLevel.ERROR, ex.getMessage());
        System.debug(LoggingLevel.ERROR, ex.getStackTraceString());
        return this;
    }

    private static String formatExceptionMessage(Exception ex) {
        return 'Exception {message}. Stack: {stack}'
            .replace('{message}', ex.getMessage())
            .replace('{stack}', ex.getStackTraceString());
    }

    global ExceptionMessage build() {
        return this.auraExceptionMessage;
    }
}