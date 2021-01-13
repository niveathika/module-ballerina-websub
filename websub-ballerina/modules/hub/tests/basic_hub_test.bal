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

import ballerina/http;
import ballerina/test;

// todo: Rename HubListener
listener Listener functionWithArgumentsListener = new(9090);

service /websubhub on functionWithArgumentsListener {

    remote function onRegisterTopic(RegisterTopicMessage message)
                                returns TopicRegistrationSuccess|error {
        if (message.topic == "test") {
            return TopicRegistrationSuccess;
        } else {
            return error("Registration Failed!");
        }
    }
}


@test:Config {
}
function testRegistrationSuccess() returns @tainted error? {
    http:Client httpClient = new("http://localhost:9090/websubhub");
    http:Request request = new;
    request.setTextPayload("hub.mode=register&hub.topic=test", "application/x-www-form-urlencoded");

    var response = check httpClient->post("/", request);
    if (response is http:Response) {
        test:assertEquals(response.statusCode, 202);
    } else {
        //todo assert fail
    }
}