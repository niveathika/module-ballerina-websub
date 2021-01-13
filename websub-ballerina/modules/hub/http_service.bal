// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/encoding;
import ballerina/http;
import ballerina/log;
import ballerina/java;

service class HttpService {
    private HubService hubService;
    private boolean isSubscriptionAvailable;
    private boolean isUnsubscriptionAvailable;

    public isolated function init(HubService hubService) {
        self.hubService = hubService;

        string[] methodNames = getServiceMethodNames(hubService);
        foreach var methodName in methodNames {
            if (methodName == "onSubscription") {
                self.isSubscriptionAvailable = true;
            } else {
                self.isSubscriptionAvailable = false;
            }

            if (methodName == "onUnsubscription") {
                self.isUnsubscriptionAvailable = true;
            } else {
               self.isUnsubscriptionAvailable = false;
            }
        }
    }

    isolated resource function post .(http:Caller caller, http:Request request) {
        http:Response response = new;

        var reqFormParamMap = request.getFormParams();
        map<string> params = reqFormParamMap is map<string> ? reqFormParamMap : {};

        string mode = params[HUB_MODE] ?: "";
        match mode {
            MODE_REGISTER => {
                string topic = "";
                var topicFromParams = params[HUB_TOPIC];
                if topicFromParams is string {
                    var decodedValue = encoding:decodeUriComponent(topicFromParams, "UTF-8");
                    topic = decodedValue is string ? decodedValue : topicFromParams;
                }
                RegisterTopicMessage msg = {
                    topic: topic
                };

                TopicRegistrationSuccess|error registerStatus = callRegisterMethod(self.hubService, msg);
                if (registerStatus is error) {
                    response.statusCode = http:STATUS_BAD_REQUEST;
                    string errorMessage = registerStatus.message();
                    response.setTextPayload(errorMessage);
                    log:print("Topic registration unsuccessful at Hub for Topic [" + topic + "]: " + errorMessage);
                } else {
                    response.statusCode = http:STATUS_ACCEPTED;
                    log:print("Topic registration successful at Hub, for topic[" + topic + "]");
                }
                var responseError = caller->respond(response);
                if (responseError is error) {
                    log:printError("Error responding remote topic registration status", err = responseError);
                }            
            }
            _ => {
                response.statusCode = http:STATUS_BAD_REQUEST;
                string errorMessage = "The request need to include valid `hub.mode` form param";
                response.setTextPayload(errorMessage);
                log:print("Hub request unsuccessful :" + errorMessage);
            }
        }
    }
}

isolated function getServiceMethodNames(HubService hubService) returns string[] = @java:Method {
    'class: "org.ballerinalang.net.websub.hub2.NativeServiceDispatcher"
} external;

isolated function callRegisterMethod(HubService hubService, RegisterTopicMessage msg)
returns TopicRegistrationSuccess|error = @java:Method {
    'class: "org.ballerinalang.net.websub.hub2.NativeServiceDispatcher"
} external;
