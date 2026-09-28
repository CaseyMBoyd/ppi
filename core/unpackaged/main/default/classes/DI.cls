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
 *    Dependency Injection like mechanism for apex classes
 *
 * CHANGE LOG
 *
 *    [Version; Date; Author; Description]
 *    v1.0; 10-3-18; pjendrzyca/Forefront; Initial Bfeatureuild
 *
 **/

public class DI {

    private static Map<Type, Object> services;

    static {
        services = new Map<Type, Object>();
    }

    public static Object inject(Type key, Object returns) {
        return Test.isRunningTest() && services.containsKey(key)
                ? services.get(key)
                : returns;
    }

    @TestVisible
    private static Mock mock(Type stubbed) {
        Mock mock = new Mock();
        Object stub = Test.createStub(stubbed, mock);
        mock.setStub(stub);
        services.put(stubbed, stub);
        return mock;
    }

    public class Mock implements StubProvider {
        public Object stub { get; private set; }

        private Boolean isStubbing = false;
        private Boolean ignoreArgumentValues = false;
        private MethodSignature currentMethodSignature;

        private Map<MethodSignature, ValueProvider> valueByMethod = new Map<MethodSignature, ValueProvider>();
        private Map<String, ValueProvider> providerByMethodName = new Map<String, ValueProvider>();

        public void setStub(Object stub) {
            this.stub = stub;
        }

        public Object handleMethodCall(
                Object stubbedObject,
                String stubbedMethodName,
                Type returnType,
                List<Type> listOfParamTypes,
                List<String> listOfParamNames,
                List<Object> listOfArgs
        ) {
            MethodSignature signature = new MethodSignature(
                    stubbedMethodName,
                    returnType,
                    listOfParamTypes,
                    listOfParamNames,
                    listOfArgs,
                    ignoreArgumentValues
            );

            // support for void methods
            if (returnType.getName() == 'void') {
                return null;
            }

            if (isStubbing) {
                currentMethodSignature = signature;
                return null;
            }

            ValueProvider valueProvider = valueByMethod.get(signature);
            valueProvider.incrementCalls();

            if (valueProvider.isException) {
                throw (Exception) valueProvider.value;
            }

            return valueProvider.value;
        }

        public void startStubbing() {
            isStubbing = true;
        }

        public void stopStubbing() {
            isStubbing = false;
        }

        public void ignoreArgumentValues(Boolean shouldIgnore) {
            ignoreArgumentValues = shouldIgnore;
        }

        public ValueProvider when(Object value) {
            return new ValueProvider(this);
        }

        public void addMethodValue(ValueProvider provider) {
            valueByMethod.put(currentMethodSignature, provider);
            providerByMethodName.put(
                    currentMethodSignature.methodName,
                    provider
            );
        }
    }

    public class MethodSignature {
        private String methodName { get; private set; }
        private Type returnType { get; private set; }
        private List<Type> paramTypes { get; private set; }
        private List<String> paramsNames { get; private set; }
        private List<Object> args { get; private set; }
        private Boolean ignoreArgumentValues { get; private set; }

        public MethodSignature(
                String methodName,
                Type returnType,
                List<Type> paramTypes,
                List<String> paramNames,
                List<Object> args,
                Boolean ignoreArgumentValues
        ) {
            this.methodName = methodName;
            this.returnType = returnType;
            this.paramsNames = paramNames;
            this.paramTypes = paramTypes;
            this.args = args;
            this.ignoreArgumentValues = ignoreArgumentValues;
        }

        public Boolean equals(Object obj) {
            if (!(obj instanceof MethodSignature))
                return false;

            MethodSignature toCompare = (MethodSignature) obj;

            Boolean isEqual =
                    this.methodName == toCompare.methodName &&
                            this.returnType == toCompare.returnType &&
                            this.paramTypes == toCompare.paramTypes &&
                            this.paramsNames == toCompare.paramsNames;

            if (ignoreArgumentValues) {
                return isEqual;
            } else {
                return isEqual & toCompare.args == this.args;
            }
        }

        public Integer hashCode() {
            Integer hash =
                    37 * methodName.hashCode() +
                            5 * returnType.hashCode() +
                            paramsNames.hashCode() +
                            paramTypes.hashCode();

            if (!ignoreArgumentValues) {
                return hash + args.hashCode();
            }

            return hash;
        }
    }

    public class ValueProvider {
        public Object value { get; private set; }
        public Boolean isException { get; private set; }
        public Integer called { get; private set; }

        private Mock mock;

        public ValueProvider(Mock mock) {
            this.isException = false;
            this.mock = mock;
            this.called = 0;
        }

        public void incrementCalls() {
            this.called += 1;
        }

        public void thenReturn(Object value) {
            this.value = value;
            this.mock.addMethodValue(this);
        }

        public void thenThrow(Exception ex) {
            this.value = ex;
            this.isException = true;
            this.mock.addMethodValue(this);
        }
    }

}