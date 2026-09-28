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
	*    Test suite for stream utility class 
	*
	* CHANGE LOG
	*
	*    [Version; Date; Author; Description]
	*    v1.0; 20.12.18; pjendrzyca/Forefront; Initial Build
	*
**/

@IsTest
public class Stream_TEST {
    private static Integer counter = 0;

    @IsTest
    static void testBehavior(){
        // given
        List<Account> accounts = new List<Account>{
            new Account(Id = generateFakeId(Account.SObjectType), Name = 'test-1'),
            new Account(Id = generateFakeId(Account.SObjectType), Name = 'test-2'),
            new Account(Id = generateFakeId(Account.SObjectType), Name = 'test-3')
        };

        Stream accountsStream = Stream.of(accounts);

        // when & then
        System.assertEquals(accounts, accountsStream.toList());
        System.assertEquals(accounts[0], accountsStream.toMap().get(accounts[0].Id));
        System.assertEquals(accounts[0], accountsStream.toMap(Account.Name).get('test-1'));
        System.assertEquals(3, accountsStream.ids().size());
        System.assertEquals(3, accountsStream.toSet(Account.Name).size());
        System.assertEquals(true, accountsStream.toSet(Account.Name).contains('test-1'));
        System.assertEquals(true, accountsStream.toSet(Account.Name).contains('test-2'));
        System.assertEquals(true, accountsStream.toSet(Account.Name).contains('test-3'));

        System.assertEquals(true, Stream.of(new List<Account>()).toSet(Account.Name).isEmpty());
        System.assertEquals(true, accountsStream.toListBy(Account.Name).contains('test-3'));
        System.assertEquals(true, accountsStream.toMapByIds(Account.Id).containsKey(accounts[0].Id));

        System.assertEquals(true, Stream.of(new List<Account>()).toSet(Account.Name).isEmpty());

        System.assertEquals(2, Stream.getChunkedList(Stream.of(accounts).toListBy(Account.Name), 2).size());
    }

    public static String generateFakeId(SObjectType sType) {
        String numberString = String.valueOf(counter++);
        String prefix = sType.getDescribe().getKeyPrefix();
        return prefix + '0'.repeat(12 - numberString.length()) + numberString;
    }
}