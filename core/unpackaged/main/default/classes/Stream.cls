/**
	* Copyright (c) 2017 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author pjendrzyca/Forefront
	* @version 1.0
	* @description
	*
	* PURPOSE
	*
	*    Utility class to help manipulate SObject lists. Introducing very simplified functional programming paradigm
	*
	* TEST CLASS
	*
	*    Stream_TEST
	*
	* CHANGE LOG
	*
	*    [Version; Date; Author; Description]
	*    v1.0; 11-23-18; pjendrzyca/Forefront; Initial Build
	*
**/

public class Stream {

    private List<SObject> sobjects;

    public static Stream of(List<SObject> sObjects) {
        return new Stream(sObjects);
    }

    private Stream(List<SObject> sobjects) {
        this.sobjects = new List<SObject>(sobjects);
    }

    public List<SObject> toList() {
        return sobjects;
    }

    public List<String> toListBy(SObjectField field) {
        List<String> strings = new List<String>();

        for (SObject so : sobjects) {
            strings.add(String.valueOf(so.get(field)));
        }

        return strings;
    }

    public Map<Id, SObject> toMap() {
        return new Map<Id, SObject>(sobjects);
    }

    public Map<String, SObject> toMap(SObjectField field) {
        return groupByString(field);
    }

    public Map<Id, SObject> toMapByIds(SObjectField field) {
        return groupById(field);
    }

    public Set<Id> ids() {
        return new Map<Id, SObject>(sobjects).keySet();
    }

    public Set<Id> ids(SObjectField field) {
        return toSetOfIds(field);
    }

    public Set<Id> toSetOfIds(SObjectField field) {
        return groupById(field).keySet();
    }

    public Set<String> toSet(SObjectField field) {
        return groupByString(field).keySet();
    }

    public Set<String> toSet(SObjectField parent, SObjectField field) {
        Set<String> values = new Set<String>();

        for (SObject so : sobjects) {
            SObject parentSObject = so.getSObject(parent);
            values.add((String) parentSObject.get(field));
        }
        return values;
    }

    public static List<List<String>> getChunkedList(List<String> listToChunk, Integer upperLimit) {
        List<List<String>> result = new List<List<String>>();
        List<String> chunk;
        for (Integer i = 0; i < listToChunk.size(); i++) {
            if(Math.mod(i, upperLimit) == 0){
                chunk = new List<String>{
                        listToChunk[i]
                };
                result.add(chunk);
            }
            else {
                chunk.add(listToChunk[i]);
            }
        }

        return result;
    }

    private Map<String, SObject> groupByString(SObjectField field) {
        Map<String, SObject> m = new Map<String, SObject>();

        for (SObject so : sobjects) {
            m.put(
                    (String) so.get(field),
                    so
            );
        }
        return m;
    }

    private Map<Id, SObject> groupById(SObjectField field) {
        Map<Id, SObject> m = new Map<Id, SObject>();

        for (SObject so : sobjects) {
            m.put(
                    (Id) so.get(field),
                    so
            );
        }
        return m;
    }

}