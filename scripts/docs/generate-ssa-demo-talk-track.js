const fs = require("fs");
const path = require("path");
const {
  AlignmentType,
  BorderStyle,
  Document,
  Footer,
  Header,
  HeadingLevel,
  LevelFormat,
  PageBreak,
  PageNumber,
  Packer,
  Paragraph,
  ShadingType,
  Table,
  TableCell,
  TableRow,
  TextRun,
  VerticalAlign,
  WidthType,
} = require("docx");

const repoRoot = path.resolve(__dirname, "..", "..");
const sourcePath = path.join(
  repoRoot,
  "specs",
  "ssa-earnings-integrity-case-review-v2",
  "ssa-earnings-integrity-40-minute-demo-talk-track.md",
);
const outputPath = process.env.SSA_DEMO_DOCX_OUTPUT || sourcePath.replace(/\.md$/i, ".docx");
const contentWidth = 10240;
const navy = "174A6E";
const teal = "007F7B";
const paleBlue = "EAF3F8";
const paleTeal = "E8F4F2";
const paleGold = "FFF4D6";
const gray = "58636D";
const lightGray = "D5DDE3";

function inlineRuns(text, options = {}) {
  const runs = [];
  const tokenPattern = /(\*\*[^*]+\*\*|`[^`]+`)/g;
  let cursor = 0;
  let match;

  while ((match = tokenPattern.exec(text)) !== null) {
    if (match.index > cursor) {
      runs.push(new TextRun({ text: text.slice(cursor, match.index), ...options }));
    }

    const token = match[0];
    if (token.startsWith("**")) {
      runs.push(new TextRun({ text: token.slice(2, -2), bold: true, ...options }));
    } else {
      runs.push(
        new TextRun({
          text: token.slice(1, -1),
          font: "Consolas",
          color: navy,
          shading: { fill: paleBlue, type: ShadingType.CLEAR },
          ...options,
        }),
      );
    }
    cursor = tokenPattern.lastIndex;
  }

  if (cursor < text.length) {
    runs.push(new TextRun({ text: text.slice(cursor), ...options }));
  }

  return runs.length ? runs : [new TextRun({ text, ...options })];
}

function bodyParagraph(text, options = {}) {
  return new Paragraph({
    spacing: { after: 140, line: 300 },
    ...options,
    children: inlineRuns(text),
  });
}

function quoteParagraph(text) {
  return new Paragraph({
    spacing: { before: 80, after: 160, line: 300 },
    indent: { left: 360, right: 180 },
    border: {
      left: { style: BorderStyle.SINGLE, size: 18, color: teal, space: 12 },
    },
    shading: { fill: paleTeal, type: ShadingType.CLEAR },
    children: inlineRuns(text, { italics: true, color: "23434F" }),
  });
}

function headingParagraph(level, text) {
  const headingByLevel = {
    2: HeadingLevel.HEADING_1,
    3: HeadingLevel.HEADING_2,
    4: HeadingLevel.HEADING_3,
  };
  return new Paragraph({
    heading: headingByLevel[level] || HeadingLevel.HEADING_3,
    keepNext: true,
    children: [new TextRun(text)],
  });
}

function makeTable(rows) {
  const columnCount = Math.max(...rows.map((row) => row.length));
  const baseWidth = Math.floor(contentWidth / columnCount);
  const columnWidths = Array(columnCount).fill(baseWidth);
  columnWidths[columnCount - 1] += contentWidth - baseWidth * columnCount;
  const border = { style: BorderStyle.SINGLE, size: 4, color: lightGray };
  const borders = { top: border, bottom: border, left: border, right: border };

  return new Table({
    width: { size: contentWidth, type: WidthType.DXA },
    columnWidths,
    rows: rows.map(
      (row, rowIndex) =>
        new TableRow({
          tableHeader: rowIndex === 0,
          cantSplit: true,
          children: columnWidths.map(
            (columnWidth, columnIndex) =>
              new TableCell({
                width: { size: columnWidth, type: WidthType.DXA },
                borders,
                verticalAlign: VerticalAlign.CENTER,
                margins: { top: 90, bottom: 90, left: 110, right: 110 },
                shading:
                  rowIndex === 0
                    ? { fill: navy, type: ShadingType.CLEAR }
                    : rowIndex % 2 === 0
                      ? { fill: "F5F8FA", type: ShadingType.CLEAR }
                      : undefined,
                children: [
                  new Paragraph({
                    spacing: { after: 0, line: 250 },
                    children: inlineRuns(row[columnIndex] || "", {
                      bold: rowIndex === 0,
                      color: rowIndex === 0 ? "FFFFFF" : "1F2933",
                      size: 19,
                    }),
                  }),
                ],
              }),
          ),
        }),
    ),
  });
}

function parseTable(lines, startIndex) {
  const rows = [];
  let index = startIndex;
  while (index < lines.length && /^\|.*\|\s*$/.test(lines[index])) {
    const cells = lines[index]
      .trim()
      .slice(1, -1)
      .split("|")
      .map((cell) => cell.trim());
    if (!cells.every((cell) => /^:?-{3,}:?$/.test(cell))) {
      rows.push(cells);
    }
    index += 1;
  }
  return { table: makeTable(rows), nextIndex: index };
}

function parseMarkdown(markdown) {
  const lines = markdown.replace(/\r\n/g, "\n").split("\n");
  const purposeIndex = lines.findIndex((line) => line === "## Purpose and Positioning");
  const children = [];
  let index = purposeIndex >= 0 ? purposeIndex : 0;

  while (index < lines.length) {
    const line = lines[index].trimEnd();
    if (!line.trim()) {
      index += 1;
      continue;
    }

    const heading = /^(#{2,4})\s+(.+)$/.exec(line);
    if (heading) {
      children.push(headingParagraph(heading[1].length, heading[2]));
      index += 1;
      continue;
    }

    if (line.startsWith("> ")) {
      const quoteLines = [];
      while (index < lines.length && lines[index].trimStart().startsWith("> ")) {
        quoteLines.push(lines[index].trimStart().slice(2));
        index += 1;
      }
      children.push(quoteParagraph(quoteLines.join(" ")));
      continue;
    }

    if (/^\|.*\|\s*$/.test(line)) {
      const parsed = parseTable(lines, index);
      children.push(parsed.table);
      children.push(new Paragraph({ spacing: { after: 120 } }));
      index = parsed.nextIndex;
      continue;
    }

    if (/^-\s+/.test(line)) {
      children.push(
        new Paragraph({
          numbering: { reference: "demo-bullets", level: 0 },
          spacing: { after: 80, line: 280 },
          children: inlineRuns(line.replace(/^-\s+/, "")),
        }),
      );
      index += 1;
      continue;
    }

    const paragraphLines = [line.trim()];
    index += 1;
    while (
      index < lines.length &&
      lines[index].trim() &&
      !/^(#{2,4})\s+/.test(lines[index]) &&
      !lines[index].trimStart().startsWith("> ") &&
      !/^\|.*\|\s*$/.test(lines[index]) &&
      !/^-\s+/.test(lines[index])
    ) {
      paragraphLines.push(lines[index].trim());
      index += 1;
    }
    children.push(bodyParagraph(paragraphLines.join(" ")));
  }

  return children;
}

function titlePage() {
  return [
    new Paragraph({ spacing: { before: 950, after: 260 }, alignment: AlignmentType.CENTER, children: [new TextRun({ text: "SSA Earnings Integrity Case Review", bold: true, color: navy, size: 48, font: "Aptos Display" })] }),
    new Paragraph({ spacing: { after: 420 }, alignment: AlignmentType.CENTER, children: [new TextRun({ text: "40-Minute Demonstration Talk Track", bold: true, color: teal, size: 34, font: "Aptos Display" })] }),
    new Paragraph({ spacing: { after: 120 }, alignment: AlignmentType.CENTER, children: [new TextRun({ text: "Dynamics 365 Customer Service + Dataverse", color: gray, size: 25 })] }),
    new Paragraph({ spacing: { after: 600 }, alignment: AlignmentType.CENTER, children: [new TextRun({ text: "Configurable SSA-oriented demonstration using fictional data", color: gray, italics: true, size: 22 })] }),
    new Paragraph({
      spacing: { before: 120, after: 180, line: 310 },
      border: { top: { style: BorderStyle.SINGLE, size: 10, color: teal, space: 12 }, bottom: { style: BorderStyle.SINGLE, size: 10, color: teal, space: 12 } },
      shading: { fill: paleGold, type: ShadingType.CLEAR },
      children: [new TextRun({ text: "Positioning: This guide presents one working configuration built to make platform capabilities tangible. It is not a prescribed SSA process or a claim of production readiness.", bold: true, color: "5C4300", size: 22 })],
    }),
    new Paragraph({ spacing: { before: 520, after: 80 }, children: [new TextRun({ text: "Hero case", bold: true, color: navy }), new TextRun("  EIR-2025-0041 - Robert Hargrove")] }),
    new Paragraph({ spacing: { after: 80 }, children: [new TextRun({ text: "Audience", bold: true, color: navy }), new TextRun("  SSA program, operations, integrity, technology, and leadership stakeholders")] }),
    new Paragraph({ spacing: { after: 80 }, children: [new TextRun({ text: "Duration", bold: true, color: navy }), new TextRun("  40 minutes, plus questions")] }),
    new Paragraph({ spacing: { after: 80 }, children: [new TextRun({ text: "Prepared", bold: true, color: navy }), new TextRun("  August 12, 2026")] }),
    new Paragraph({ children: [new PageBreak()] }),
  ];
}

async function main() {
  const markdown = fs.readFileSync(sourcePath, "utf8");
  const body = [...titlePage(), ...parseMarkdown(markdown)];
  const doc = new Document({
    creator: "GitHub Copilot",
    title: "SSA Earnings Integrity Case Review - 40-Minute Demonstration Talk Track",
    subject: "Presenter guide for the Federal Earnings Fraud Dynamics 365 demonstration",
    description: "A configurable SSA-oriented demonstration talk track using fictional data.",
    styles: {
      default: { document: { run: { font: "Aptos", size: 22, color: "1F2933" } } },
      paragraphStyles: [
        { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true, run: { font: "Aptos Display", size: 34, bold: true, color: navy }, paragraph: { spacing: { before: 340, after: 170 }, outlineLevel: 0, keepNext: true } },
        { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true, run: { font: "Aptos Display", size: 28, bold: true, color: teal }, paragraph: { spacing: { before: 260, after: 130 }, outlineLevel: 1, keepNext: true } },
        { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true, run: { font: "Aptos", size: 23, bold: true, color: navy }, paragraph: { spacing: { before: 190, after: 90 }, outlineLevel: 2, keepNext: true } },
      ],
    },
    numbering: {
      config: [
        {
          reference: "demo-bullets",
          levels: [
            {
              level: 0,
              format: LevelFormat.BULLET,
              text: "•",
              alignment: AlignmentType.LEFT,
              style: { paragraph: { indent: { left: 480, hanging: 240 } } },
            },
          ],
        },
      ],
    },
    sections: [
      {
        properties: {
          page: {
            size: { width: 12240, height: 15840 },
            margin: { top: 900, right: 1000, bottom: 900, left: 1000, header: 450, footer: 450 },
          },
        },
        headers: {
          default: new Header({
            children: [
              new Paragraph({
                border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: teal, space: 5 } },
                children: [new TextRun({ text: "SSA Earnings Integrity Case Review | Demonstration Talk Track", color: gray, size: 17 })],
              }),
            ],
          }),
        },
        footers: {
          default: new Footer({
            children: [
              new Paragraph({
                alignment: AlignmentType.CENTER,
                children: [new TextRun({ text: "Fictional demonstration data | Page ", color: gray, size: 17 }), new TextRun({ children: [PageNumber.CURRENT], color: gray, size: 17 })],
              }),
            ],
          }),
        },
        children: body,
      },
    ],
  });

  fs.writeFileSync(outputPath, await Packer.toBuffer(doc));
  console.log(`Created ${outputPath}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});