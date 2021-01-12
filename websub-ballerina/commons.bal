// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/crypto;
import ballerina/encoding;
import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/mime;
import ballerina/stringutils;

# Parameter `hub.mode` representing the mode of the request from hub to subscriber or subscriber to hub.
const string HUB_MODE = "hub.mode";

# Subscription change or intent verification request parameter 'hub.topic'' representing the topic relevant to the for
# which the request is initiated.
const string HUB_TOPIC = "hub.topic";

# Subscription change request parameter 'hub.callback' representing the callback to which notification should happen.
const string HUB_CALLBACK = "hub.callback";

# Subscription request parameter 'hub.lease_seconds' representing the period for which the subscription is expected to
# be active.
const string HUB_LEASE_SECONDS = "hub.lease_seconds";

# Subscription parameter 'hub.secret' representing the secret key to use for authenticated content distribution.
const string HUB_SECRET = "hub.secret";

# `hub.mode` value indicating "subscription" mode, to subscribe to updates for a topic.
const string MODE_SUBSCRIBE = "subscribe";

# `hub.mode` value indicating "unsubscription" mode, to unsubscribe to updates for a topic.
const string MODE_UNSUBSCRIBE = "unsubscribe";

const string X_HUB_SIGNATURE = "X-Hub-Signature";


const string REMOTE_PUBLISHING_MODE_DIRECT = "direct";
const string REMOTE_PUBLISHING_MODE_FETCH = "fetch";

const string X_HUB_UUID = "X-Hub-Uuid";
const string X_HUB_TOPIC = "X-Hub-Topic";

const string ACCEPT_HEADER = "Accept";
const string ACCEPT_LANGUAGE_HEADER = "Accept-Language";
const string CONTENT_TYPE = "Content-Type";

const string ANN_NAME_WEBSUB_SUBSCRIBER_SERVICE_CONFIG = "SubscriberServiceConfig";
const ANNOT_FIELD_TARGET = "target";
const ANNOT_FIELD_ACCEPT = "accept";
const ANNOT_FIELD_ACCEPT_LANGUAGE = "acceptLanguage";
const ANNOT_FIELD_CALLBACK = "callback";
const ANNOT_FIELD_LEASE_SECONDS = "leaseSeconds";
const ANNOT_FIELD_SECRET = "secret";
const ANNOT_FIELD_SUBSCRIBE_ON_STARTUP = "subscribeOnStartUp";
const ANNOT_FIELD_EXPECT_INTENT_VERIFICATION = "expectIntentVerification";
const ANNOT_FIELD_HUB_CLIENT_CONFIG = "hubClientConfig";
const ANNOT_FIELD_PUBLISHER_CLIENT_CONFIG = "publisherClientConfig";

# The identifier to be used to identify the cryptographic hash algorithm.
public type SignatureMethod SHA1|SHA256;

# The constant used to represent SHA-1 cryptographic hash algorithm
public const string SHA1 = "SHA1";

# The constant used to represent SHA-256 cryptographic hash algorithm
public const string SHA256 = "SHA256";

///////////////////////////////// Custom Webhook/Extension specific constants /////////////////////////////////
# The identifier to be used to identify the topic for dispatching with custom subscriber services.
public type TopicIdentifier TOPIC_ID_HEADER|TOPIC_ID_PAYLOAD_KEY|TOPIC_ID_HEADER_AND_PAYLOAD;

# `TopicIdentifier` indicating dispatching based solely on a header of the request.
public const TOPIC_ID_HEADER = "TOPIC_ID_HEADER";

# `TopicIdentifier` indicating dispatching based solely on a value for a key in the JSON payload of the request.
public const TOPIC_ID_PAYLOAD_KEY = "TOPIC_ID_PAYLOAD_KEY";

# `TopicIdentifier` indicating dispatching based on a combination of header and values specified for a key/key(s) in
# the JSON payload of the request.
public const TOPIC_ID_HEADER_AND_PAYLOAD = "TOPIC_ID_HEADER_AND_PAYLOAD";

///////////////////////////////////////////////////////////////////
//////////////////// WebSub Subscriber Commons ////////////////////
///////////////////////////////////////////////////////////////////
#  representing an intent verification request received.
#
# + mode - The mode specified in the intent verification request, subscription or unsubscription
# + topic - The topic for which intent is verified to subscribe/unsubscribe
# + challenge - The challenge to be echoed to verify intent to subscribe/unsubscribe
# + leaseSeconds - The lease seconds period for which a subscription will be active if intent verification
#                  is being done for subscription
# + request - An `http:Request` received for intent verification
public class IntentVerificationRequest {

    public string mode = "";
    public string topic = "";
    public string challenge = "";
    public int leaseSeconds = 0;
    public http:Request request = new;

    # Builds the response for the request, verifying intention to subscribe, if the topic matches that expected.
    # ```ballerina
    #  http:Response response = request.buildSubscriptionVerificationResponse("<TOPIC_TO_VERIFY_FOR>");
    # ```
    #
    # + expectedTopic - The topic for which subscription should be accepted
    # + return - An `http:Response`, which to the hub verifying/denying intent to subscribe
    public isolated function buildSubscriptionVerificationResponse(string expectedTopic) returns http:Response {
        return buildIntentVerificationResponse(self, MODE_SUBSCRIBE, expectedTopic);
    }

    # Builds the response for the request, verifying intention to unsubscribe, if the topic matches that expected.
    # ```ballerina
    # http:Response response = request.buildUnsubscriptionVerificationResponse("<TOPIC_TO_VERIFY_FOR>");
    # ```
    #
    # + expectedTopic - The topic for which unsubscription should be accepted
    # + return - An `http:Response`, which to for the hub verifying/denying intent to unsubscribe
    public isolated function buildUnsubscriptionVerificationResponse(string expectedTopic) returns http:Response {
        return buildIntentVerificationResponse(self, MODE_UNSUBSCRIBE, expectedTopic);
    }
}

# Function to build intent verification response for subscription/unsubscription requests sent.
#
# + intentVerificationRequest - The intent verification request from the hub
# + mode - The mode (subscription/unsubscription) for which a request was sent
# + topic - The intended topic for which subscription change should be verified
# + return - An `http:Response`, which to the hub verifying/denying intent to subscripe/unsubscribe
isolated function buildIntentVerificationResponse(IntentVerificationRequest intentVerificationRequest, string mode,
                                         string topic) returns http:Response {
    http:Response response = new;
    var decodedTopic = encoding:decodeUriComponent(intentVerificationRequest.topic, "UTF-8");
    string reqTopic = decodedTopic is string ? decodedTopic : topic;

    string reqMode = intentVerificationRequest.mode;
    string challenge = <@untainted>intentVerificationRequest.challenge;

    if (reqMode == mode && reqTopic == topic) {
        response.statusCode = http:STATUS_ACCEPTED;
        response.setTextPayload(challenge);
    } else {
        response.statusCode = http:STATUS_NOT_FOUND;
    }
    return response;
}

# Function to build the data source and validate the signature for requests received at the callback.
#
# + request - The request received
# + serviceType - The service for which the request was rceived
# + return - An `error`, if an error occurred in extraction or signature validation failed or else `()`
isolated function processWebSubNotification(http:Request request, SubscriberService serviceType) returns @tainted error? {
    SubscriberServiceConfiguration? subscriberConfig = retrieveSubscriberServiceAnnotations(serviceType);
    string secret = subscriberConfig?.secret ?: "";
    // Build the data source before responding to the content delivery requests automatically
    var payload = request.getTextPayload();

    if (!request.hasHeader(X_HUB_SIGNATURE)) {
        if (secret != "") {
            return error WebSubError(X_HUB_SIGNATURE + " header not present for subscription added specifying " + HUB_SECRET);
        }
        return;
    }

    string xHubSignature = request.getHeader(X_HUB_SIGNATURE);
    if (secret == "" && xHubSignature != "") {
        log:print("Ignoring " + X_HUB_SIGNATURE + " value since secret is not specified.");
        return;
    }

    if (payload is string) {
        return validateSignature(xHubSignature, payload, secret);
    } else {
        string errCause = payload.message();
        return error WebSubError("Error extracting notification payload as string for signature validation: " + errCause);
    }
}

# Validates the signature header included in the notification.
#
# + xHubSignature - The X-Hub-Signature header included in the notification request from the hub
# + stringPayload - The string representation of the notification payload received
# + secret - The secret used when subscribing
# + return - An `error`, if an error occurred in extraction or signature validation failed or else `()`
isolated function validateSignature(string xHubSignature, string stringPayload, string secret) returns error? {
    string[] splitSignature = stringutils:split(xHubSignature, "=");
    string method = splitSignature[0];
    string signature = stringutils:replace(xHubSignature, method + "=", "");
    string generatedSignature = "";

    if (stringutils:equalsIgnoreCase(method, SHA1)) {
        generatedSignature = crypto:hmacSha1(stringPayload.toBytes(), secret.toBytes()).toBase16();
    } else if (stringutils:equalsIgnoreCase(method, SHA256)) {
        generatedSignature = crypto:hmacSha256(stringPayload.toBytes(), secret.toBytes()).toBase16();
    } else {
        return error WebSubError("Unsupported signature method: " + method);
    }

    if (!stringutils:equalsIgnoreCase(signature, generatedSignature)) {
        return error WebSubError("Signature validation failed: Invalid Signature!");
    }
    return;
}

# Represents the WebSub Content Delivery Request received.
#
# + request - The HTTP POST request received as the notification
public class Notification {

    private http:Request request = new;

    # Retrieves the query parameters of the content delivery request as a map.
    # ```ballerina
    # map<string[]> payload = notification.getTextPayload();
    # ```
    #
    # + return - String-constrained array map of the query params
    public isolated function getQueryParams() returns map<string[]> {
        return self.request.getQueryParams();
    }

    # Retrieves the `mime:Entity` associated with the content delivery request.
    # ```ballerina
    # mime:Entity|error payload = notification.getEntity();
    # ```
    #
    # + return - The `mime:Entity` of the request or else an `error` if entity construction fails
    public isolated function getEntity() returns mime:Entity|error {
        return self.request.getEntity();
    }

    # Returns whether the requested header key exists in the header map of the content delivery request.
    # ```ballerina
    # boolean payload = notification.hasHeader("name");
    # ```
    #
    # + headerName - The header name
    # + return - `true` if the specified header key exists or else `false`
    public isolated function hasHeader(string headerName) returns boolean {
        return self.request.hasHeader(headerName);
    }

    # Returns the value of the specified header. If the specified header key maps to multiple values, the first of
    # these values is returned.
    # ```ballerina
    # string payload = notification.getHeader("name");
    # ```
    #
    # + headerName - The header name
    # + return - The first header value for the specified header name or else panic if no header is found. Ideally, the
    #            `Notification.hasHeader()` needs to be used to check the existence of a header initially.
    public isolated function getHeader(string headerName) returns @tainted string {
        return self.request.getHeader(headerName);
    }

    # Retrieves all the header values to which the specified header key maps to.
    # ```ballerina
    # string[] headersNames = notification.getHeaders("name");
    # ```
    #
    # + headerName - The header name
    # + return - The header values the specified header key maps to or else panic if no header is found. Ideally, the
    #            `Notification.hasHeader()` needs to be used to check the existence of a header initially.
    public isolated function getHeaders(string headerName) returns @tainted string[] {
        return self.request.getHeaders(headerName);
    }

    # Retrieves all the names of the headers present in the content delivery request.
    # ```ballerina
    # string[] headersNames = notification.getHeaderNames();
    # ```
    #
    # + return - An array of all the header names
    public isolated function getHeaderNames() returns @tainted string[] {
        return self.request.getHeaderNames();
    }

    # Retrieves the type of the payload of the content delivery request (i.e: the `content-type` header value).
    # ```ballerina
    # string contentType = notification.getContentType();
    # ```
    #
    # + return - The `content-type` header value as a `string`
    public isolated function getContentType() returns @tainted string {
        return self.request.getContentType();
    }

    # Extracts `json` payload from the content delivery request.
    # ```ballerina
    # json|error payload = notification.getJsonPayload();
    # ```
    #
    # + return - The `json` payload or else an `error` in case of errors.
    #            If the content; type is not JSON, an `error` is returned.
    public isolated function getJsonPayload() returns @tainted json|error {
        return self.request.getJsonPayload();
    }

    # Extracts `xml` payload from the content delivery request.
    # ```ballerina
    # xml|error result = notification.getXmlPayload();
    # ```
    #
    # + return - The `xml` payload or else an `error` in case of errors.
    #            If the content; type is not XML, an `error` is returned.
    public isolated function getXmlPayload() returns @tainted xml|error {
        return self.request.getXmlPayload();
    }

    # Extracts `text` payload from the content delivery request.
    # ```ballerina
    # string|error result = notification.getTextPayload();
    # ```
    #
    # + return - The payload as a `text` or else  an `error` in case of errors.
    #            If the content type is not of type text, an `error` is returned.
    public isolated function getTextPayload() returns @tainted string|error {
        return self.request.getTextPayload();
    }

    # Retrieves the request payload as a `ByteChannel` except in the case of multiparts.
    # ```ballerina
    # io:ReadableByteChannel|error result = notification.getByteChannel();
    # ```
    #
    # + return - A byte channel from which the message payload can be read or esle an `error` in case of errors
    public isolated function getByteChannel() returns @tainted io:ReadableByteChannel|error {
        return self.request.getByteChannel();
    }

    # Retrieves the request payload as a `byte[]`.
    # ```ballerina
    # byte[]|error payload = notification.getBinaryPayload();
    # ```
    #
    # + return - The message payload as a `byte[]` or else an `error` in case of errors
    public isolated function getBinaryPayload() returns @tainted byte[]|error {
        return self.request.getBinaryPayload();
    }

    # Retrieves the form parameters from the content delivery request as a `map`.
    # ```ballerina
    # map<string>|error result = notification.getFormParams();
    # ```
    #
    # + return - The form params as a `map` or else an `error` in case of errors
    public isolated function getFormParams() returns @tainted map<string>|error {
        return self.request.getFormParams();
    }
}

# Retrieves hub and topic URLs from the `http:response` from a publisher to a discovery request.
#
# + response - An `http:Response` received
# + return - A `(topic, hubs)` if parsing and extraction is successful or else an `error` if not
public function extractTopicAndHubUrls(http:Response response) returns @tainted [string, string[]]|error {
    string[] linkHeaders = [];
    if (response.hasHeader("Link")) {
        linkHeaders = response.getHeaders("Link");
    }
    
    if (response.statusCode == http:STATUS_NOT_ACCEPTABLE) {
        return error WebSubError("Content negotiation failed.Accept and/or Accept-Language headers mismatch");
    }
    
    if (linkHeaders.length() == 0) {
        return error WebSubError("Link header unavailable in discovery response");
    }

    int hubIndex = 0;
    string[] hubs = [];
    string topic = "";
    string[] linkHeaderConstituents = [];
    if (linkHeaders.length() == 1) {
        linkHeaderConstituents = stringutils:split(linkHeaders[0], ",");
    } else {
        linkHeaderConstituents = linkHeaders;
    }

    foreach var link in linkHeaderConstituents {
        string[] linkConstituents = stringutils:split(link, ";");
        if (linkConstituents[1] != "") {
            string url = linkConstituents[0].trim();
            url = stringutils:replace(url, "<", "");
            url = stringutils:replace(url, ">", "");
            if (stringutils:contains(linkConstituents[1], "rel=\"hub\"")) {
                hubs[hubIndex] = url;
                hubIndex += 1;
            } else if (stringutils:contains(linkConstituents[1], "rel=\"self\"")) {
                if (topic != "") {
                    return error WebSubError("Link Header contains > 1 self URLs");
                } else {
                    topic = url;
                }
            }
        }
    }

    if (hubs.length() > 0 && topic != "") {
        return [topic, hubs];
    }
    return error WebSubError("Hub and/or Topic URL(s) not identified in link header of discovery response");
}

# Record representing a WebSub subscription change request.
#
# + topic - The topic for which the subscription/unsubscription request is sent
# + callback - The callback which should be registered/unregistered for the subscription/unsubscription request sent
# + leaseSeconds - The lease period for which the subscription is expected to be active
# + secret - The secret to be used for authenticated content distribution with this subscription
public type SubscriptionChangeRequest record {|
    string topic = "";
    string callback = "";
    int leaseSeconds = 0;
    string secret = "";
|};

# Record representing subscription/unsubscription details if a subscription/unsubscription request is successful.
#
# + hub - The hub at which the subscription/unsubscription was successful
# + topic - The topic for which the subscription/unsubscription was successful
# + response - The response from the hub to the subscription/unsubscription request
public type SubscriptionChangeResponse record {|
    string hub = "";
    string topic = "";
    http:Response response;
|};

///////////////////////////////////////////////////////////////////
//////////////////// WebSub Publisher Commons /////////////////////
///////////////////////////////////////////////////////////////////


isolated function retrieveSubscriberServiceAnnotations(SubscriberService serviceType) returns SubscriberServiceConfiguration? {
    typedesc<any> serviceTypedesc = typeof serviceType;
    return serviceTypedesc.@SubscriberServiceConfig;
}

isolated function isSuccessStatusCode(int statusCode) returns boolean {
    return (200 <= statusCode && statusCode < 300);
}
