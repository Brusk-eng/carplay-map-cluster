#!/usr/bin/env node
'use strict';
/**
 * Offline format-gate checks (no car required).
 * Expects PNGs in /tmp/carplay-fmt-test/ from tools/mk-format-fixtures.py
 * or generates minimal synthetics itself.
 */
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const {
    decodePNG, detectDashboard
} = require('../native/carplay-map/carplay-map-cluster.js');

const DIR = process.env.FMT_TEST_DIR || '/tmp/carplay-fmt-test';
const fmt = {
    mapX0: 0.10, mapY0: 0.12, mapX1: 0.58, mapY1: 0.88,
    rX0: 0.645, rY0: 0.06, rX1: 0.985, rY1: 0.95,
    satTh: 40, tMap: 5, tCells: 7, cellTh: 15, cols: 4, rows: 4, step: 70
};

const expect = {
    synth_map_dashboard: true,
    synth_weather: false,
    synth_fullscreen: false
};

function ensureFixtures() {
    const need = Object.keys(expect).some((n) => !fs.existsSync(path.join(DIR, n + '.png')));
    if (!need) return;
    const py = path.join(__dirname, 'mk-format-fixtures.py');
    execFileSync('python3', [py, DIR], { stdio: 'inherit' });
}

function run() {
    ensureFixtures();
    let fail = 0;
    for (const [name, want] of Object.entries(expect)) {
        const p = path.join(DIR, name + '.png');
        const img = decodePNG(fs.readFileSync(p));
        img.order = 'rgba';
        const d = detectDashboard(img, fmt);
        const ok = d.dashboard === want;
        console.log((ok ? 'PASS' : 'FAIL'), name, 'want=' + want, 'got=' + d.dashboard,
            'widget=' + !!d.widget, 'sat=' + d.satMap.toFixed(1),
            'navBlue%=' + (100 * d.navBlue).toFixed(2), 'cells=' + d.cells);
        if (!ok) fail++;
    }
    const weatherPhoto = path.join(DIR, 'weather_widgets.png');
    if (fs.existsSync(weatherPhoto)) {
        const img = decodePNG(fs.readFileSync(weatherPhoto));
        img.order = 'rgba';
        const d = detectDashboard(img, fmt);
        const ok = d.dashboard === false && d.widget === true;
        console.log((ok ? 'PASS' : 'FAIL'), 'weather_widgets_photo', 'want=reject+widget',
            'got dashboard=' + d.dashboard + ' widget=' + d.widget);
        if (!ok) fail++;
    }
    if (fail) {
        console.error(fail + ' failure(s)');
        process.exit(1);
    }
    console.log('OK — format gate');
}

run();
