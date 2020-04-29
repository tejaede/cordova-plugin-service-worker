/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

function SyncRegistration(options) {
    options = options || {};
    if (typeof options === "string") {
        this.tag = options;
    } else {
        this.tag = options.tag || '';
    }
}

SyncRegistration.prototype.unregister = function() {
    var tag = this.tag;
    return new Promise(function(resolve, reject) {
	if (typeof cordova !== 'undefined') {
	    cordova.exec(resolve, null, 'BackgroundSync', 'unregister', [tag]);
	} else {
        cordovaExec("unregisterSync", {type: "periodic", tag: tag}, function (data, error) {
            if (error) {
                reject(error);
            } else {
                resolve(data);
            }
        });
	}
    });
};

if (typeof cordova !== 'undefined') {
    module.exports = SyncRegistration;
}
