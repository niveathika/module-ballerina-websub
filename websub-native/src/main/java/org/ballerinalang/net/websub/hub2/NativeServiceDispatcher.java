/*
 * Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package org.ballerinalang.net.websub.hub2;

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.Module;
import io.ballerina.runtime.api.async.StrandMetadata;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.MethodType;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;

import java.util.ArrayList;
import java.util.concurrent.CountDownLatch;

public class NativeServiceDispatcher {

    public static BArray getServiceMethodNames(BObject bHubService) {
        // Todo: Need to validate return type and params type of onSubscribe and onUnSubscribe?
        ArrayList<BString> methodNamesList = new ArrayList<>();
        for (MethodType method : bHubService.getType().getMethods()) {
            methodNamesList.add(StringUtils.fromString(method.getName()));
        }

        return ValueCreator.createArrayValue(methodNamesList.toArray(BString[]::new));
    }

    public static Object callRegisterMethod(Environment env, BObject bHubService, BMap<BString, Object> message) {

        Module module = ModuleUtils.getModule();
        StrandMetadata metadata = new StrandMetadata(module.getOrg(), module.getName(), module.getVersion(),
                                                     "onRegisterTopic");
        CountDownLatch latch = new CountDownLatch(1);
        CallableUnitCallback callback = new CallableUnitCallback(latch);

        env.getRuntime().invokeMethodAsync(bHubService, "onRegisterTopic", null, null, callback, message);

        try {
            latch.await();
        } catch (InterruptedException e) {
            // Ignore
        }
        // todo: Returns Index 1 out of bounds for index 1
        return callback.getResult();
    }

}
