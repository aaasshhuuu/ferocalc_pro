// FeroCalc Verified FD Rate Engine — Pure Node.js PDF Text Extractor
// Extracts text tokens from unencrypted PDF files with FlateDecode streams without external binary dependencies.

'use strict';

const zlib = require('zlib');

function unescapePdfString(str) {
  return str
    .replace(/\\([0-7]{1,3})/g, (_, oct) => String.fromCharCode(parseInt(oct, 8)))
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\r')
    .replace(/\\t/g, '\t')
    .replace(/\\b/g, '\b')
    .replace(/\\f/g, '\f')
    .replace(/\\\(/g, '(')
    .replace(/\\\)/g, ')')
    .replace(/\\\\/g, '\\');
}

function decodeHexString(hex) {
  const clean = hex.replace(/\s+/g, '');
  const bytes = [];
  for (let i = 0; i < clean.length; i += 2) {
    const byte = clean.slice(i, i + 2);
    if (byte.length === 1) {
      bytes.push(parseInt(byte + '0', 16));
    } else {
      bytes.push(parseInt(byte, 16));
    }
  }
  return Buffer.from(bytes).toString('latin1');
}

/**
 * Extracts an ordered list of text tokens from a PDF Buffer or pre-extracted text string.
 *
 * @param {Buffer|string} input - PDF file Buffer or text string
 * @returns {string[]} Array of non-empty extracted text tokens
 */
function extractPdfTokens(input) {
  if (!input) return [];

  // If already a plain string that doesn't start with %PDF-, tokenize by whitespace
  if (typeof input === 'string' && !input.startsWith('%PDF-')) {
    return input
      .split(/\s+/)
      .map(s => s.replace(/[\x00-\x1f\x7f-\x9f]/g, '').trim())
      .filter(Boolean);
  }

  const buf = Buffer.isBuffer(input) ? input : Buffer.from(input, 'latin1');
  if (buf.length < 5 || buf.slice(0, 5).toString('latin1') !== '%PDF-') {
    throw new Error('Not a valid PDF document (missing %PDF- header)');
  }

  const str = buf.toString('latin1');
  const streamRegex = /stream\r?\n([\s\S]*?)\r?\nendstream/g;
  let m;
  const tokens = [];

  while ((m = streamRegex.exec(str)) !== null) {
    const rawStream = Buffer.from(m[1], 'latin1');
    let content = '';
    try {
      content = zlib.inflateSync(rawStream).toString('latin1');
    } catch {
      // Stream is uncompressed or uses another filter
      content = rawStream.toString('latin1');
    }

    const btRegex = /BT([\s\S]*?)ET/g;
    let btm;
    while ((btm = btRegex.exec(content)) !== null) {
      const block = btm[1];

      // Tj operator: (text) Tj or <hex> Tj
      const tjRegex = /(?:\(((?:[^()\\]|\\.)*)\)|<([0-9a-fA-F\s]+)>)\s*Tj/g;
      let tjm;
      while ((tjm = tjRegex.exec(block)) !== null) {
        if (tjm[1] !== undefined) {
          tokens.push(unescapePdfString(tjm[1]));
        } else if (tjm[2] !== undefined) {
          tokens.push(decodeHexString(tjm[2]));
        }
      }

      // TJ operator: [(text) 20 <hex> -10] TJ
      const arrayRegex = /\[([\s\S]*?)\]\s*TJ/g;
      let arrm;
      while ((arrm = arrayRegex.exec(block)) !== null) {
        const inner = arrm[1];
        const innerRegex = /(?:\(((?:[^()\\]|\\.)*)\)|<([0-9a-fA-F\s]+)>)/g;
        let itm;
        let combined = '';
        while ((itm = innerRegex.exec(inner)) !== null) {
          if (itm[1] !== undefined) {
            combined += unescapePdfString(itm[1]);
          } else if (itm[2] !== undefined) {
            combined += decodeHexString(itm[2]);
          }
        }
        if (combined) tokens.push(combined);
      }
    }
  }

  return tokens
    .map(s => s.replace(/[\x00-\x1f\x7f-\x9f]/g, '').trim())
    .filter(Boolean);
}

module.exports = {
  extractPdfTokens,
  unescapePdfString,
  decodeHexString,
};
