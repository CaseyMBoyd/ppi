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
	*    Handles creation of service instances
	*
	* CHANGE LOG
	*
	*    [Version; Date; Author; Description]
	*    v1.0; 2021-04-27; pjendrzyca/Forefront; Initial Build
	*
**/

public abstract class ServiceFactory {

    private static Map<Type, Object> services;

    static {
        services = new Map<Type, Object>();
    }

    public static Object get(Type serviceType) {
        Object instance = services.get(serviceType);

        if (instance == null) {
            instance = DI.inject(serviceType, serviceType.newInstance());
            services.put(serviceType, instance);
        }
        return instance;
    }

}