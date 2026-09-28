/**
	* Copyright (c) 2022 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author Mateusz Kieczkowski/Forefront
	* @version 1.0
	* @description
	*
	* PURPOSE
	* 
	*
	* 
	* TEST CLASS 
	* 
	* 
	*  
	* ENTRY POINTS 
	*  
	*    
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 08.06.2022; Mateusz Kieczkowski/Forefront; Initial Build
	* 
**/
@IsTest
private class CollectionUtils_TEST {
    @IsTest
    static void testEmptyCollections() {
        // given
        List<String> nullArray;
        List<String> emptyArray = new List<String>();
        List<String> nonEmptyArray = new List<String>{ 'abc' };

        // when & then
        System.assertEquals(true, CollectionUtils.isEmpty(nullArray));
        System.assertEquals(true, CollectionUtils.isEmpty(emptyArray));
        System.assertEquals(false, CollectionUtils.isEmpty(nonEmptyArray));

        System.assertEquals(false, CollectionUtils.notEmpty(nullArray));
        System.assertEquals(false, CollectionUtils.notEmpty(emptyArray));
        System.assertEquals(true, CollectionUtils.notEmpty(nonEmptyArray));

        System.assert(CollectionUtils.emptyOnNull(nullArray).isEmpty());

        Set<String> nullSet = new Set<String>();
        Set<String> nonEmptySet = new Set<String>{ '1' };

        System.assertEquals(true, CollectionUtils.isEmpty(nullSet));
        System.assertEquals(false, CollectionUtils.isEmpty(nonEmptySet));

        System.assertEquals(false, CollectionUtils.notEmpty(nullSet));
        System.assertEquals(true, CollectionUtils.notEmpty(nonEmptySet));

        Set<Id> nullSetId = new Set<Id>();
        Set<Id> nonEmptySetId = new Set<Id>{
                TestUtils.generateFakeId(Account.SObjectType)
        };

        System.assertEquals(true, CollectionUtils.isEmpty(nullSetId));
        System.assertEquals(false, CollectionUtils.isEmpty(nonEmptySetId));

        System.assertEquals(false, CollectionUtils.notEmpty(nullSetId));
        System.assertEquals(true, CollectionUtils.notEmpty(nonEmptySetId));
    }

    @IsTest
    static void testArraySlicingWithSobjects() {
        // given
        List<Account> accounts = new List<Account>{
                new Account(Name = '1'),
                new Account(Name = '2'),
                new Account(Name = '3'),
                new Account(Name = '4'),
                new Account(Name = '5')
        };

        // when
        List<Account> sliced = (List<Account>) CollectionUtils.slice(
                2,
                4,
                accounts
        );

        // then
        System.assertEquals(2, sliced.size());
        System.assertEquals('3', sliced[0].Name);
        System.assertEquals('4', sliced[1].Name);

        // test different slices
        System.assertEquals(1, CollectionUtils.slice(0, 1, accounts).size());
        System.assertEquals(2, CollectionUtils.slice(3, 5, accounts).size());
        System.assertEquals(5, CollectionUtils.slice(0, 5, accounts).size());
        System.assertEquals(3, CollectionUtils.slice(1, 4, accounts).size());
    }

    @IsTest
    static void testArraySplice() {
        // given
        List<Account> accounts = new List<Account>{
                new Account(Name = '1'),
                new Account(Name = '2'),
                new Account(Name = '3'),
                new Account(Name = '4'),
                new Account(Name = '5')
        };

        // when
        List<Account> sliced = (List<Account>) CollectionUtils.splice(
                2,
                4,
                accounts
        );

        // then
        System.assertEquals(3, sliced.size());
        System.assertEquals('3', sliced[0].Name);
        System.assertEquals('4', sliced[1].Name);
        System.assertEquals('5', sliced[2].Name);

        // test different slices
        System.assertEquals(
                1,
                CollectionUtils.splice(4, 1000, accounts).size()
        );
        System.assertEquals(
                5,
                CollectionUtils.splice(0, 1000, accounts).size()
        );
        System.assertEquals(1, CollectionUtils.splice(1, 1, accounts).size());
        System.assertEquals(3, CollectionUtils.splice(1, 3, accounts).size());
        System.assertEquals(0, CollectionUtils.splice(1, 0, accounts).size());
    }

    @IsTest
    static void testIntersect() {
        // given
        Id id_1 = TestUtils.generateFakeId(Account.SObjectType);
        Id id_2 = TestUtils.generateFakeId(Account.SObjectType);
        Id id_3 = TestUtils.generateFakeId(Account.SObjectType);
        Id id_4 = TestUtils.generateFakeId(Account.SObjectType);

        Set<Id> intersect;

        // when & then
        intersect = CollectionUtils.intersect(
                new Set<Id>{ id_1, id_2 },
                new Set<Id>{ id_3, id_4 }
        );
        System.assertEquals(0, intersect.size());

        intersect = CollectionUtils.intersect(
                new Set<Id>{ id_1, id_2 },
                new Set<Id>{ id_2, id_3, id_4 }
        );
        System.assertEquals(1, intersect.size());
        System.assert(intersect.contains(id_2));

        intersect = CollectionUtils.intersect(
                new Set<Id>{ id_1, id_2, id_3 },
                new Set<Id>{ id_2, id_3, id_4 }
        );
        System.assertEquals(2, intersect.size());
        System.assert(intersect.contains(id_2));
        System.assert(intersect.contains(id_3));

        intersect = CollectionUtils.intersect(
                new Set<Id>{ id_1, id_2, id_3, id_4 },
                new Set<Id>{ id_1, id_2, id_3, id_4 }
        );
        System.assertEquals(4, intersect.size());
        System.assert(intersect.contains(id_1));
        System.assert(intersect.contains(id_2));
        System.assert(intersect.contains(id_3));
        System.assert(intersect.contains(id_4));
    }

    @IsTest
    static void testIntersectStrings() {
        // given
        String string_1 = 'a';
        String string_2 = 'b';
        String string_3 = 'c';
        String string_4 = 'd';

        Set<String> intersect;

        // when & then
        intersect = CollectionUtils.intersect(
                new Set<String>{ string_1, string_2 },
                new Set<String>{ string_3, string_4 }
        );
        System.assertEquals(0, intersect.size());

        intersect = CollectionUtils.intersect(
                new Set<String>{ string_1, string_2 },
                new Set<String>{ string_2, string_3, string_4 }
        );
        System.assertEquals(1, intersect.size());
        System.assert(intersect.contains(string_2));

        intersect = CollectionUtils.intersect(
                new Set<String>{ string_1, string_2, string_3 },
                new Set<string>{ string_2, string_3, string_4 }
        );
        System.assertEquals(2, intersect.size());
        System.assert(intersect.contains(string_2));
        System.assert(intersect.contains(string_3));

        intersect = CollectionUtils.intersect(
                new Set<String>{ string_1, string_2, string_3, string_4 },
                new Set<String>{ string_1, string_2, string_3, string_4 }
        );
        System.assertEquals(4, intersect.size());
        System.assert(intersect.contains(string_1));
        System.assert(intersect.contains(string_2));
        System.assert(intersect.contains(string_3));
        System.assert(intersect.contains(string_4));
    }

    @IsTest
    static void testRemoveStrings() {
        // given
        Set<String> empty = new Set<String>();
        Set<String> abcd = new Set<String>{ 'a', 'b', 'c', 'd' };
        Set<String> ab = new Set<String>{ 'a', 'b' };
        Set<String> cd = new Set<String>{ 'c', 'd' };

        // when & then
        System.assertEquals(abcd, CollectionUtils.remove(abcd, empty));
        System.assertEquals(cd, CollectionUtils.remove(abcd, ab));
        System.assertEquals(ab, CollectionUtils.remove(abcd, cd));
    }

    @IsTest
    static void testRemoveIds() {
        // given
        Id a = TestUtils.generateFakeId(Account.SObjectType);
        Id b = TestUtils.generateFakeId(Account.SObjectType);
        Id c = TestUtils.generateFakeId(Account.SObjectType);
        Id d = TestUtils.generateFakeId(Account.SObjectType);

        Set<Id> empty = new Set<Id>();
        Set<Id> abcd = new Set<Id>{ a, b, c, d };
        Set<Id> ab = new Set<Id>{ a, b };
        Set<Id> cd = new Set<Id>{ c, d };

        // when & then
        System.assertEquals(abcd, CollectionUtils.remove(abcd, empty));
        System.assertEquals(cd, CollectionUtils.remove(abcd, ab));
        System.assertEquals(ab, CollectionUtils.remove(abcd, cd));
    }

    @IsTest
    static void testConvertSetOfIdsToStrings() {
        Id a = TestUtils.generateFakeId(Account.SObjectType);
        Id b = TestUtils.generateFakeId(Account.SObjectType);
        Id c = TestUtils.generateFakeId(Account.SObjectType);
        Id d = TestUtils.generateFakeId(Account.SObjectType);

        Set<Id> ids = new Set<Id>{ a, b, c, d };

        // when & then
        Set<String> converted = CollectionUtils.convertToStrings(ids);

        System.assert(converted.contains((String) a));
        System.assert(converted.contains((String) b));
        System.assert(converted.contains((String) c));
        System.assert(converted.contains((String) d));
    }

    @IsTest
    static void testConvertSetStringsToIds() {
        String a = TestUtils.generateFakeId(Account.SObjectType);
        String b = TestUtils.generateFakeId(Account.SObjectType);
        String c = TestUtils.generateFakeId(Account.SObjectType);
        String d = TestUtils.generateFakeId(Account.SObjectType);

        Set<String> strings = new Set<String>{ a, b, c, d };

        // when & then
        Set<Id> converted = CollectionUtils.convertToIds(strings);

        System.assert(converted.contains((Id) a));
        System.assert(converted.contains((Id) b));
        System.assert(converted.contains((Id) c));
        System.assert(converted.contains((Id) d));
    }

    @IsTest
    static void testJoinTrimmedSet() {
        // given
        Set<String> toJoin = new Set<String>{ 'join  ', 'me  \n \t' };

        // when & then
        System.assertEquals(
                'join me',
                CollectionUtils.joinTrimmed(toJoin, ' ')
        );
    }

    @IsTest
    static void testJoinTrimmedList() {
        // given
        List<String> toJoin = new List<String>{ 'join  ', 'me  \n \t' };

        // when & then
        System.assertEquals(
                'join me',
                CollectionUtils.joinTrimmed(toJoin, ' ')
        );
    }
}