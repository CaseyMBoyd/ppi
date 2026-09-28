/**
 * Copyright (c) 2018 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @version 1.0
 * @description
 *
 * PURPOSE
 *
 *    Provides default values for primitives in case of null value
 *
 * TEST CLASS
 *
 *    Optional_TEST
 *
 * CHANGE LOG
 *
 *    [Version; Date; Author; Description]
 *    v1.0; 06.12.18; pjendrzyca/Forefront; Initial Build
 *
 **/

global class Optional {
    global static Boolean isNull(Object val) {
        return val == null;
    }

    global static String of(String val, String def) {
        return isNull(val) ? def : val;
    }

    global static Date of(Date val, Date def) {
        return isNull(val) ? def : val;
    }

    global static Datetime of(Datetime val, Datetime def) {
        return isNull(val) ? def : val;
    }

    global static Decimal of(Decimal val, Decimal def) {
        return isNull(val) ? def : val;
    }

    global static Integer of(Integer val, Integer def) {
        return isNull(val) ? def : val;
    }

    global static Double of(Double val, Double def) {
        return isNull(val) ? def : val;
    }

    global static Boolean of(Boolean val, Boolean def) {
        return isNull(val) ? def : val;
    }
}