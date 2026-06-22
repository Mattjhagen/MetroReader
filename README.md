# MetroReader

MetroReader is a brutalist, typography-forward reading application for iOS. It strips away the digital chrome of traditional e-readers, flattening EPUBs and PDFs into a single, unified navigational model. It treats books as continuous scrolls of content rather than simulated paper.

## Philosophy

Most digital readers try to emulate physical books. They fail. MetroReader goes the other way: it embraces the digital medium.

- **No Pages:** Content is a single, continuous vertical scroll.
- **No Chrome:** Progress bars and "Chapter X of Y" counters are eliminated. You read until you stop. Momentum is felt, not measured.
- **No Format Anxiety:** Whether the file is an EPUB or a PDF, the reading experience is identical. The format is a technical detail, not a user experience.
- **Bold Typography:** Swiss-inspired, brutalist design utilizing system typography to maximize legibility and visual hierarchy.

## Architecture & Resilience

Behind the stark UI is a robust, temporally stable data model designed to survive the chaos of long-term usage.

### 1. The Taxonomy of Failure
Digital files break. MetroReader expects this. The system uses an explicit failure taxonomy to gracefully handle issues:
- `missingFile`: The physical file was deleted from disk.
- `corruptFile`: The PDF is malformed.
- `partialParse`: The EPUB is unreadable or malformed.
- `unsupportedFormat`: The file type is not supported.

Instead of crashing or silently hiding broken books, the Library visually degrades the tile, providing honest, human-readable explanations (e.g., "File appears damaged").

### 2. Explainable State & Provenance
The library does not use invisible magic to fix itself. It uses an **Explainable State Layer**. 
- A surgical event-sourcing layer (`LibraryEvent`) tracks when books are imported, removed, merged, or repaired. 
- Long-pressing a book reveals a lightweight "Truth Sheet" showing its technical metadata alongside a plain-language system status (e.g., "Recovered after file was restored"). 
- During background reconciliation passes, the system communicates silently. If no repairs were needed, it says nothing.

### 3. Human-Level Grouping (`clusterId`)
Books are grouped conceptually by a dynamically computed `clusterId` (Title + Author), allowing the system to understand that a PDF and an EPUB of the same title are the same *reading experience*. 
However, **format isolation is strictly enforced**. Reading progress will sync across identical copies (e.g., EPUB to EPUB), but will never cross-pollinate between differing pagination models (e.g., PDF to EPUB), preventing destructive progress jumps.

## Requirements
- iOS 17.0+
- Xcode 15.0+

## Building the Project
1. Open `MetroReader.xcodeproj`.
2. Select the `MetroReader_iOS` scheme.
3. Build and Run on an iOS Simulator or Device.

*(Note: The `ZIPFoundation` dependency is currently configured for iOS. Mac Catalyst support requires further target configuration.)*
