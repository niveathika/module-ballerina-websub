// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/test;
import ballerina/http;

const string HASH_KEY = "secret";

@test:Config { 
    groups: ["contentHashRetrieval"]
}
isolated function testContentHashForSha1() returns @tainted error? {
    byte[] hashedContent = check retrieveContentHash(SHA1, HASH_KEY, "This is sample content");
    test:assertTrue(hashedContent.length() > 0);
}

@test:Config { 
    groups: ["contentHashRetrieval"]
}
isolated function testContentHashForSha256() returns @tainted error? {
    byte[] hashedContent = check retrieveContentHash(SHA_256, HASH_KEY, "This is sample content");
    test:assertTrue(hashedContent.length() > 0);
}

@test:Config { 
    groups: ["contentHashRetrieval"]
}
isolated function testContentHashForSha384() returns @tainted error? {
    byte[] hashedContent = check retrieveContentHash(SHA_384, HASH_KEY, "This is sample content");
    test:assertTrue(hashedContent.length() > 0);
}

@test:Config { 
    groups: ["contentHashRetrieval"]
}
isolated function testContentHashForSha512() returns @tainted error? {
    byte[] hashedContent = check retrieveContentHash(SHA_512, HASH_KEY, "This is sample content");
    test:assertTrue(hashedContent.length() > 0);
}

@test:Config { 
    groups: ["contentHashRetrieval"]
}
isolated function testContentHashError() returns @tainted error? {
    byte[]|error hashedContent = retrieveContentHash("xyz", HASH_KEY, "This is sample content");
    string expectedErrorMsg = "Unrecognized hashning-method [xyz] found";
    if (hashedContent is error) {
        test:assertEquals(hashedContent.message(), expectedErrorMsg);
    } else {
        test:assertFail("Content hash generation not properly working for unidentified hash-method");
    }
}

var validSubscriberServiceDeclaration = @SubscriberServiceConfig { target: "http://0.0.0.0:9191/common/discovery", leaseSeconds: 36000 } 
                              service object {
    isolated remote function onEventNotification(ContentDistributionMessage event) 
                        returns Acknowledgement|SubscriptionDeletedError? {
        return ACKNOWLEDGEMENT;
    }
};

@test:Config { 
    groups: ["serviceAnnotationRetrieval"]
}
function testSubscriberServiceAnnotationRetrievalSuccess() returns @tainted error? {
    SubscriberServiceConfiguration? configuration = retrieveSubscriberServiceAnnotations(validSubscriberServiceDeclaration);
    test:assertTrue(configuration is SubscriberServiceConfiguration, "service annotation retrieval failed for valid service declaration");
}

var invalidSubscriberServiceDeclaration = service object {
    isolated remote function onEventNotification(ContentDistributionMessage event) 
                        returns Acknowledgement|SubscriptionDeletedError? {
        return ACKNOWLEDGEMENT;
    }
};

@test:Config { 
    groups: ["serviceAnnotationRetrieval"]
}
function testSubscriberServiceAnnotationRetrievalFailure() returns @tainted error? {
    SubscriberServiceConfiguration? configuration = retrieveSubscriberServiceAnnotations(invalidSubscriberServiceDeclaration);
    test:assertTrue(configuration is (), "service annotation retrieval success for invalid service declaration");
}

@test:Config { 
    groups: ["servicePathRetrieval"]
}
isolated function testServicePathRetrievalForString() returns @tainted error? {
    string[]|string servicePath = retrieveServicePath("subscriber");
    test:assertTrue(servicePath is string, "Service path retrieval failed for 'string'");
}

@test:Config { 
    groups: ["servicePathRetrieval"]
}
isolated function testServicePathRetrievalForStringArray() returns @tainted error? {
    string[]|string servicePath = retrieveServicePath(["subscriber", "foo", "bar"]);
    test:assertTrue(servicePath is string[], "Service path retrieval failed for 'string array'");
}

@test:Config { 
    groups: ["servicePathRetrieval"]
}
isolated function testServicePathRetrievalForEmptyServicePath() returns @tainted error? {
    string[]|string servicePath = retrieveServicePath(());
    test:assertTrue(servicePath is string, "Service path retrieval failed for 'empty service path'");
}

@test:Config { 
    groups: ["completeServicePathRetrieval"]
}
isolated function testCompleteServicePathRetrievalWithString() returns @tainted error? {
    string expectedServicePath = "/subscriber";
    string generatedServicePath = retrieveCompleteServicePath("subscriber");
    test:assertEquals(generatedServicePath, expectedServicePath, "Generated service-path does not matched expected service-path"); 
}

@test:Config { 
    groups: ["completeServicePathRetrieval"]
}
isolated function testCompleteServicePathRetrievalWithStringArray() returns @tainted error? {
    string expectedServicePath = "/subscriber/foo/bar";
    string generatedServicePath = retrieveCompleteServicePath(["subscriber", "foo", "bar"]);
    test:assertEquals(generatedServicePath, expectedServicePath, "Generated service-path does not matched expected service-path"); 
}

@test:Config { 
    groups: ["retrieveCallbackUrl"]
}
isolated function testCallbackUrlRetrievalWithNoCallback() returns @tainted error? {
    string expectedCallbackUrl = "http://0.0.0.0:9090/subscriber";
    string retrievedCallbackUrl = retrieveCallbackUrl((), false, "subscriber", 9090, {});
    test:assertEquals(retrievedCallbackUrl, expectedCallbackUrl, "Retrieved callback url does not match expected callback url");
}

@test:Config { 
    groups: ["retrieveCallbackUrl"]
}
isolated function testCallbackUrlRetrievalWithCallbackAppendingDisabled() returns @tainted error? {
    string expectedCallbackUrl = "http://0.0.0.0:9090/subscriber";
    string retrievedCallbackUrl = retrieveCallbackUrl("http://0.0.0.0:9090/subscriber", false, "subscriber", 9090, {});
    test:assertEquals(retrievedCallbackUrl, expectedCallbackUrl, "Retrieved callback url does not match expected callback url");
}

@test:Config { 
    groups: ["retrieveCallbackUrl"]
}
isolated function testCallbackUrlRetrievalWithCallbackAppendingEnabled() returns @tainted error? {
    string expectedCallbackUrl = "http://0.0.0.0:9090/subscriber/foo";
    string retrievedCallbackUrl = retrieveCallbackUrl("http://0.0.0.0:9090", true, ["subscriber", "foo"], 9090, {});
    test:assertEquals(retrievedCallbackUrl, expectedCallbackUrl, "Retrieved callback url does not match expected callback url");
}

@test:Config { 
    groups: ["callbackUrlGeneration"]
}
isolated function testCallbackUrlGenerationHttpsWithNoHostConfig() returns @tainted error? {
    http:ListenerConfiguration config = {
        secureSocket: {
            key: {
                path: "tests/resources/ballerinaKeystore.pkcs12",
                password: "ballerina"
            }
        }
    };
    string expectedCallbackUrl = "https://0.0.0.0:9090/subscriber";
    string generatedCallbackUrl = generateCallbackUrl("subscriber", 9090, config);
    test:assertEquals(generatedCallbackUrl, expectedCallbackUrl, "Generated callback url does not match expected callback url");
}

@test:Config { 
    groups: ["callbackUrlGeneration"]
}
isolated function testCallbackUrlGenerationHttpWithNoHostConfig() returns @tainted error? {
    http:ListenerConfiguration config = {};
    string expectedCallbackUrl = "http://0.0.0.0:9090/subscriber";
    string generatedCallbackUrl = generateCallbackUrl("subscriber", 9090, config);
    test:assertEquals(generatedCallbackUrl, expectedCallbackUrl, "Generated callback url does not match expected callback url");
}

@test:Config { 
    groups: ["callbackUrlGeneration"]
}
isolated function testCallbackUrlGenerationHttpsWithHostConfig() returns @tainted error? {
    http:ListenerConfiguration config = {
        host: "192.168.1.1",
        secureSocket: {
            key: {
                path: "tests/resources/ballerinaKeystore.pkcs12",
                password: "ballerina"
            }
        }
    };
    string expectedCallbackUrl = "https://192.168.1.1:9090/subscriber";
    string generatedCallbackUrl = generateCallbackUrl("subscriber", 9090, config);
    test:assertEquals(generatedCallbackUrl, expectedCallbackUrl, "Generated callback url does not match expected callback url");
}

@test:Config { 
    groups: ["callbackUrlGeneration"]
}
isolated function testCallbackUrlGenerationHttpWithHostConfig() returns @tainted error? {
    http:ListenerConfiguration config = {
        host: "192.168.1.1"
    };
    string expectedCallbackUrl = "http://192.168.1.1:9090/subscriber";
    string generatedCallbackUrl = generateCallbackUrl("subscriber", 9090, config);
    test:assertEquals(generatedCallbackUrl, expectedCallbackUrl, "Generated callback url does not match expected callback url");
}

@test:Config { 
    groups: ["callbackUrlGeneration"]
}
isolated function testCallbackUrlForArrayTypeServicePath() returns @tainted error? {
    http:ListenerConfiguration config = {
        host: "192.168.1.1"
    };
    string expectedCallbackUrl = "http://192.168.1.1:9090/subscriber/foo/bar";
    string generatedCallbackUrl = generateCallbackUrl(["subscriber", "foo", "bar"], 9090, config);
    test:assertEquals(generatedCallbackUrl, expectedCallbackUrl, "Generated callback url does not match expected callback url");   
}

@test:Config { 
    groups: ["logCallbackUrl"]
}
isolated function testCallbackUrlLoggingSuccess() returns @tainted error? {
    boolean isLoggingEnabled = isLoggingGeneratedCallback((), ());
    test:assertTrue(isLoggingEnabled, "Callback URL logging is disabled for valid scenario");
}

@test:Config { 
    groups: ["logCallbackUrl"]
}
isolated function testCallbackUrlLoggingFailure() returns @tainted error? {
    boolean isLoggingEnabled = isLoggingGeneratedCallback("https://test.com/callback", ());
    test:assertFalse(isLoggingEnabled, "Callback URL logging is enabled for invalid scenario");
}

@test:Config { 
    groups: ["logCallbackUrl"]
}
isolated function testCallbackUrlLoggingFailureForServicePathProvided() returns @tainted error? {
    boolean isLoggingEnabled = isLoggingGeneratedCallback((), "subscriber");
    test:assertFalse(isLoggingEnabled, "Callback URL logging is enabled for invalid scenario");
}
