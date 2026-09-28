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
global class CollectionUtils {
    public class CollectionUtilsException extends Exception {
    }

    /**
     * Given to sets of ids finds elements that are both in first and second set
     *
     * @param s1
     * @param s2
     *
     * @return - Set<Id>
     */
    global static Set<Id> intersect(Set<Id> s1, Set<Id> s2) {
        if (isEmpty(s1) || isEmpty(s2)) {
            return new Set<Id>();
        }

        Set<Id> common = new Set<Id>();

        for (Id id : s1) {
            if (s2.contains(id)) {
                common.add(id);
            }
        }

        return common;
    }

    /**
     * Given to sets of strings finds elements that are both in first and second set
     *
     * @param s1
     * @param s2
     *
     * @return - Set<String>
     */
    global static Set<String> intersect(Set<String> s1, Set<String> s2) {
        if (isEmpty(s1) || isEmpty(s2)) {
            return new Set<String>();
        }

        Set<String> common = new Set<String>();

        for (String s : s1) {
            if (s2.contains(s)) {
                common.add(s);
            }
        }

        return common;
    }

    /**
     * Given to set of strings removes all elements that are in the remove set
     * Returns new set without modifying the existing one
     *
     * @param s1
     * @param s2
     *
     * @return - Set<String>
     */
    global static Set<String> remove(Set<String> all, Set<String> toRemove) {
        if (isEmpty(toRemove)) {
            return isEmpty(all) ? new Set<String>() : all;
        }

        Set<String> removed = new Set<String>();

        for (String s : all) {
            if (!toRemove.contains(s)) {
                removed.add(s);
            }
        }

        return removed;
    }

    /**
     * Given to set of ids removes all elements that are in the remove set
     * Returns new set without modifying the existing one
     *
     * @param s1
     * @param s2
     *
     * @return - Set<Id>
     */
    global static Set<Id> remove(Set<Id> all, Set<Id> toRemove) {
        if (isEmpty(toRemove)) {
            return isEmpty(all) ? new Set<Id>() : all;
        }

        Set<Id> removed = new Set<Id>();

        for (Id s : all) {
            if (!toRemove.contains(s)) {
                removed.add(s);
            }
        }

        return removed;
    }

    /**
     * Slices given array
     *
     * @param start - starting index from 0, element included
     * @param stop - stopping index from 0, element not included
     * @param collection - collection to slice
     *
     * @return
     */
    global static List<SObject> slice(
            Integer start,
            Integer stop,
            List<SObject> collection
    ) {
        start = Math.max(0, start);
        stop = Math.max(0, stop);

        List<SObject> slice = new List<SObject>();

        for (Integer i = start; i < stop; i++) {
            slice.add(collection[i]);
        }

        return slice;
    }

    /**
     * Slices given array from passed index until the count value is reached
     * or the collection ends
     *
     * @param start - starting index from 0, element included
     * @param count - number of items to get
     * @param collection - collection to slice
     *
     * @return
     */
    global static List<SObject> splice(
            Integer start,
            Integer count,
            List<SObject> collection
    ) {
        start = Math.max(0, start);
        Integer stop = Math.min(start + count, collection.size());

        List<SObject> slice = new List<SObject>();

        for (Integer i = start; i < stop; i++) {
            slice.add(collection[i]);
        }

        return slice;
    }

    global static List<Id> splice(
        Integer start,
        Integer count,
        List<Id> collection
    ) {
        start = Math.max(0, start);
        Integer stop = Math.min(start + count, collection.size());

        List<Id> slice = new List<Id>();

        for (Integer i = start; i < stop; i++) {
            slice.add(collection[i]);
        }

        return slice;
    }

    global static List<String> emptyOnNull(List<String> arr) {
        return isNull(arr) ? new List<String>() : arr;
    }

    global static Set<String> emptyOnNull(Set<String> arr) {
        return arr == null ? new Set<String>() : arr;
    }

    global static Boolean isEmpty(List<Object> arr) {
        return isNull(arr) || arr.isEmpty();
    }

    global static Boolean isNull(List<Object> arr) {
        return arr == null;
    }

    global static Boolean notEmpty(List<Object> arr) {
        return !isEmpty(arr);
    }

    global static Boolean isEmpty(Set<String> arr) {
        return arr == null || arr.isEmpty();
    }

    global static Boolean notEmpty(Set<String> arr) {
        return !isEmpty(arr);
    }

    global static Boolean isEmpty(Set<Id> arr) {
        return arr == null || arr.isEmpty();
    }

    global static Boolean notEmpty(Set<Id> arr) {
        return !isEmpty(arr);
    }

    global static Set<Id> convertToIds(Set<String> collection) {
        Set<Id> converted = new Set<Id>();

        for (String el : collection) {
            converted.add((Id) el);
        }
        return converted;
    }

    global static Set<String> convertToStrings(Set<Id> collection) {
        Set<String> converted = new Set<String>();

        for (String el : collection) {
            converted.add(el);
        }

        return converted;
    }

    global static String joinTrimmed(Set<String> toJoin, String separator) {
        List<String> trimmed = new List<String>();

        for (String str : toJoin) {
            trimmed.add(Optional.of(str, '').trim());
        }

        return String.join(trimmed, separator);
    }

    global static String joinTrimmed(List<String> toJoin, String separator) {
        List<String> trimmed = new List<String>();

        for (String str : toJoin) {
            trimmed.add(Optional.of(str, '').trim());
        }

        return String.join(trimmed, separator);
    }

    global static List<String> lowercase(List<String> arr) {
        List<String> transformed = new List<String>();

        for (String str : arr) {
            if(String.isNotBlank(str)) {
                transformed.add(str.toLowerCase());
            }
        }

        return transformed;
    }
}