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

import ballerina/log;
import ballerina/test;
import ballerina/http;

listener Listener serviceWithDefaultImplListener = new (9091);

var serviceWithDefaultImpl = @SubscriberServiceConfig { target: "http://0.0.0.0:9191/common/discovery", leaseSeconds: 36000, secret: "Kslk30SNF2AChs2" } 
                              service object {
    remote function onEventNotification(ContentDistributionMessage event) 
                        returns Acknowledgement | SubscriptionDeletedError? {
        log:print("onEventNotification invoked ", contentDistributionMessage = event);
        return {};
    }
};

@test:BeforeGroups { value:["default-method-impl"] }
function beforeGroupTwo() {
    checkpanic serviceWithDefaultImplListener.attach(serviceWithDefaultImpl, "subscriber");
}

@test:AfterGroups { value:["default-method-impl"] }
function afterGroupTwo() {
    checkpanic serviceWithDefaultImplListener.gracefulStop();
}

http:Client serviceWithDefaultImplClientEp = checkpanic new("http://localhost:9091/subscriber");

@test:Config { 
    groups: ["default-method-impl"]
}
function testOnSubscriptionValidationDefaultImpl() returns @tainted error? {
    http:Request request = new;

    var response = check serviceWithDefaultImplClientEp->get("/?hub.mode=denied&hub.reason=justToTest", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
    } else {
        test:assertFail("UnsubscriptionIntentVerification test failed");
    }
}

@test:Config {
    groups: ["default-method-impl"]
 }
function testOnIntentVerificationSuccessDefaultImpl() returns @tainted error? {
    http:Request request = new;

    var response = check serviceWithDefaultImplClientEp->get("/?hub.mode=subscribe&hub.topic=test&hub.challenge=1234", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 200);
        test:assertEquals(response.getTextPayload(), "1234");
    } else {
        test:assertFail("UnsubscriptionIntentVerification test failed");
    }
}

@test:Config {
    groups: ["default-method-impl"]
}
function testUniqueStringGeneration() returns @tainted error? {
    var generatedString = generateUniqueUrlSegment();
    log:print("Generated unique string ", value = generatedString);
    test:assertEquals(generatedString.length(), 10);
}