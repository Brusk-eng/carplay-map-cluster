#!/usr/bin/env node
// SPDX-License-Identifier: MPL-2.0
/* activate hook: refuse this tool while robertn's waze-on-cluster is installed.
 * Store/mgu-deploy rolls the install back if activate exits non-zero. */
'use strict';
var fs = require('fs');

function present() {
    try {
        if (fs.existsSync('/var/opt/waze-on-cluster/current')) return true;
        if (fs.existsSync('/var/opt/waze-on-cluster/versions')) {
            var v = fs.readdirSync('/var/opt/waze-on-cluster/versions');
            if (v && v.length) return true;
        }
    } catch (e) {}
    return false;
}

if (present()) {
    console.error('carplay-map: refused — waze-on-cluster is installed.');
    console.error('These are different apps that fight the same cluster map slot.');
    console.error('Uninstall waze-on-cluster in MGU Store, then install CarPlay map → cluster.');
    process.exit(1);
}
process.exit(0);
