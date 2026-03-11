#!/usr/bin/env node
// generate_fixtures.mjs — Generate reference JPEG fixtures using Squoosh's MozJPEG WASM
// Created by okooo5km(十里)
//
// Usage: node Scripts/generate_fixtures.mjs <squoosh_dir>
// Requires: Node.js 18+
//
// This script loads Squoosh's mozjpeg_node_enc.wasm directly and generates
// reference JPEG outputs for known RGBA inputs, enabling byte-exact parity tests.

import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { join, resolve } from 'path';

const squooshDir = process.argv[2];
if (!squooshDir) {
    console.error('Usage: node generate_fixtures.mjs <squoosh_dir>');
    process.exit(1);
}

const fixtureDir = resolve(import.meta.dirname, '..', 'Tests', 'SquooshJPEGKitTests', 'Fixtures');
mkdirSync(fixtureDir, { recursive: true });

// Load Squoosh's WASM module
const wasmPath = join(squooshDir, 'codecs', 'mozjpeg', 'enc', 'mozjpeg_node_enc.wasm');
const jsPath = join(squooshDir, 'codecs', 'mozjpeg', 'enc', 'mozjpeg_node_enc.js');

// Dynamic import of the Squoosh encoder
const initModule = (await import(jsPath)).default;
const module = await initModule();

const defaultOptions = {
    quality: 75,
    baseline: false,
    arithmetic: false,
    progressive: true,
    optimize_coding: true,
    smoothing: 0,
    color_space: 3, // YCbCr
    quant_table: 3,
    trellis_multipass: false,
    trellis_opt_zero: false,
    trellis_opt_table: false,
    trellis_loops: 1,
    auto_subsample: true,
    chroma_subsample: 2,
    separate_chroma_quality: false,
    chroma_quality: 75,
};

// Helper: create solid color RGBA buffer
function solidColor(w, h, r, g, b, a = 255) {
    const buf = Buffer.alloc(w * h * 4);
    for (let i = 0; i < w * h; i++) {
        buf[i * 4] = r;
        buf[i * 4 + 1] = g;
        buf[i * 4 + 2] = b;
        buf[i * 4 + 3] = a;
    }
    return buf;
}

// Helper: create gradient RGBA buffer
function gradient(w, h) {
    const buf = Buffer.alloc(w * h * 4);
    for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
            const i = (y * w + x) * 4;
            buf[i] = Math.round(x * 255 / Math.max(w - 1, 1));
            buf[i + 1] = Math.round(y * 255 / Math.max(h - 1, 1));
            buf[i + 2] = 128;
            buf[i + 3] = 255;
        }
    }
    return buf;
}

function encodeFixture(name, rgba, width, height, options = defaultOptions) {
    const inputStr = String.fromCharCode(...rgba);
    const result = module.encode(inputStr, width, height, options);
    const jpegData = Buffer.from(result);

    // Save RGBA input
    writeFileSync(join(fixtureDir, `${name}.rgba`), rgba);

    // Save dimensions
    const meta = { width, height, options };
    writeFileSync(join(fixtureDir, `${name}.json`), JSON.stringify(meta, null, 2));

    // Save reference JPEG
    writeFileSync(join(fixtureDir, `${name}.jpg`), jpegData);

    console.log(`Generated: ${name} (${width}x${height}) -> ${jpegData.length} bytes`);
}

// Generate fixtures
const fixtures = [
    ['solid_red_8x8', solidColor(8, 8, 255, 0, 0), 8, 8],
    ['solid_red_4x4', solidColor(4, 4, 255, 0, 0), 4, 4],
    ['solid_gray_16x16', solidColor(16, 16, 128, 128, 128), 16, 16],
    ['gradient_32x32', gradient(32, 32), 32, 32],
    ['gradient_64x64', gradient(64, 64), 64, 64],
    ['pixel_1x1', solidColor(1, 1, 128, 64, 192), 1, 1],
    ['transparent_8x8', solidColor(8, 8, 0, 0, 0, 0), 8, 8],
];

for (const [name, rgba, w, h] of fixtures) {
    encodeFixture(name, rgba, w, h);
}

// Quality variants
for (const q of [10, 50, 75, 90, 100]) {
    encodeFixture(`gradient_32x32_q${q}`, gradient(32, 32), 32, 32, { ...defaultOptions, quality: q });
}

// Quant table variants
for (const qt of [0, 1, 2, 3, 4, 5, 6, 7, 8]) {
    encodeFixture(`gradient_32x32_qt${qt}`, gradient(32, 32), 32, 32, { ...defaultOptions, quant_table: qt });
}

// Baseline
encodeFixture('gradient_32x32_baseline', gradient(32, 32), 32, 32,
    { ...defaultOptions, baseline: true, progressive: false });

console.log('\nAll fixtures generated in:', fixtureDir);
