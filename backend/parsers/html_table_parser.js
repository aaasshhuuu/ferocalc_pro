// FeroCalc Verified FD Rate Engine — Pure Node HTML Table Extractor
// Extracts <table> structures into rows and cells without external DOM libraries.

'use strict';

function decodeHtmlEntities(str) {
  if (!str) return '';
  return str
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&#x27;/g, "'")
    .replace(/&ndash;/g, '-')
    .replace(/&mdash;/g, '-')
    .replace(/&#8211;/g, '-')
    .replace(/&#8212;/g, '-');
}

/**
 * Strips HTML tags, decodes entities, and normalizes whitespace.
 */
function cleanCellText(rawHtml) {
  if (!rawHtml) return '';
  const noTags = rawHtml.replace(/<[^>]+>/g, ' ');
  const decoded = decodeHtmlEntities(noTags);
  return decoded.replace(/\s+/g, ' ').trim();
}

/**
 * Parses all <table> elements in an HTML document.
 * Returns an array of tables, where each table is an array of rows,
 * and each row is an array of cleaned cell strings.
 *
 * @param {string} html
 * @returns {Array<Array<Array<string>>>}
 */
function parseHtmlTables(html) {
  if (!html || typeof html !== 'string') return [];

  const tables = [];
  const tableRegex = /<table[^>]*>([\s\S]*?)<\/table>/gi;
  let tMatch;

  while ((tMatch = tableRegex.exec(html)) !== null) {
    const tableContent = tMatch[1];
    const rows = [];
    const rowRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
    let rMatch;

    while ((rMatch = rowRegex.exec(tableContent)) !== null) {
      const rowContent = rMatch[1];
      const cells = [];
      const cellRegex = /<(?:td|th)[^>]*>([\s\S]*?)<\/(?:td|th)>/gi;
      let cMatch;

      while ((cMatch = cellRegex.exec(rowContent)) !== null) {
        cells.push(cleanCellText(cMatch[1]));
      }

      if (cells.length > 0) {
        rows.push(cells);
      }
    }

    if (rows.length > 0) {
      tables.push(rows);
    }
  }

  return tables;
}

module.exports = {
  parseHtmlTables,
  cleanCellText,
  decodeHtmlEntities,
};
