/**
	* Copyright (c) 2022 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author jakub_cichacki/Forefront
	* @version 1.0
	* @description
**/
@IsTest
private class Optional_TEST {

    @IsTest
    static void shouldCheckIfDateIsNull() {
        //given
        Date d = Date.newInstance(1900, 1,1);

        //when
        Date result = Optional.of(null, d);

        //then
        Assert.areEqual(d, result);
    }

    @IsTest
    static void shouldCheckIfDateTimeIsNull() {
        //given
        Datetime dt = Datetime.newInstance(1900, 1,1, 1,1,1);

        //when
        Datetime result = Optional.of(null, dt);

        //then
        Assert.areEqual(dt, result);
    }

    @IsTest
    static void shouldCheckIfIntegerIsNull() {
        //given
        Integer i = 1;

        //when
        Integer result = Optional.of(null, i);

        //then
        Assert.areEqual(i, result);
    }

    @IsTest
    static void shouldCheckIfDoubleIsNull() {
        //given
        Double d = 1;

        //when
        Double result = Optional.of(null, d);

        //then
        Assert.areEqual(d, result);
    }

}