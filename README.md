# RCCU — RetroBat Collection Cleanup Utility

A PowerShell utility for maintaining RetroBat game collections, media files, and `gamelist.xml`.

RCCU is designed to help identify missing files, stale references, unused or unreferenced media, and XML inconsistencies in large RetroBat collections while keeping the original `gamelist.xml` safe.

## Why RCCU?

RCCU was created because maintaining a large RetroBat collection can leave behind a lot of things that normal cleanup tools don't necessarily understand.

Removing a game doesn't necessarily remove its media or XML entry. Adding a large media pack doesn't necessarily mean the files will be correctly associated with the games. A manual or PDF can be perfectly useful while still being completely unreferenced by `gamelist.xml`.

RCCU is designed to reconcile all of this.

It compares the files that actually exist with the working RetroBat XML, identifies what belongs together, repairs missing or broken references, and only considers media for removal after those checks have been completed.

RCCU also deliberately avoids guessing when a filename could match multiple games. Ambiguous files are reported for human review instead.

The basic idea is:

**Detect first. Protect known-good data. Repair the working XML. Verify everything. Only then touch the live XML.**

RCCU was built for large collections where doing all of this manually becomes impractical. It is a maintenance utility you can run when you need to clean up, reconcile, repair, or verify a RetroBat collection.

## When Would I Use RCCU?

RCCU is intended for situations where a RetroBat collection has grown large enough that manually maintaining the games, media, and XML becomes difficult.

Typical examples include:

- You deleted ROMs and want to remove their leftover media and XML entries.
- You added a large media pack and want to associate the files with the correct games.
- You have manuals, PDFs, screenshots, videos, or other media that exist physically but are not referenced by `gamelist.xml`.
- Your XML contains games that no longer exist on disk.
- Games exist on disk but are missing from the XML.
- You have broken or outdated media references in the XML.
- You want to normalize videos to avoid EmulationStation preview playback artifacting.
- You want to verify the collection and XML before replacing the live `gamelist.xml`.
- You have a very large collection where checking everything manually would be impractical.

RCCU is designed to be a maintenance utility that you can run when you need it rather than something that has to remain permanently installed.

## How RCCU Works

RCCU follows a staged process designed to protect the existing collection:

```text
RetroBat Collection
        ↓
Permission & Access Check
        ↓
Duplicate / Image / Video Analysis
        ↓
Copy gamelist.xml → gamelist_TEST.xml
        ↓
Media & Game Matching
        ↓
XML Repair
        ↓
Human Review / Cleanup
        ↓
Final Verification
        ↓
Back Up Original gamelist.xml
        ↓
Promote Verified TEST XML
```

Importantly, RCCU uses and modifies a copy of your current `gamelist.xml` during processing.

The current `gamelist.xml` is never used as the working XML. RCCU creates `gamelist_TEST.xml` from it and performs its repairs and verification against the TEST XML. The original `gamelist.xml` is only backed up and replaced after the repaired TEST XML passes the final verification process and promotion is approved, unless automatic mode is enabled.

## Download

**RCCU v4.31**

[Download RCCU v4.31](./RCCU_v4.31.ps1)

**Documentation**

[Download Documentation](./RCCU_v4.31_Documentation.txt)

The documentation contains the complete Stage 1–9 function and safety details for RCCU v4.31.

For the official v4.31 release, see the [RCCU v4.31 Release](https://github.com/Cutter81/RCCU-RetroBat-Collection-Cleanup-Utility/releases/tag/v4.31).

## Features

- Scans RetroBat game collections and their media folders
- Compares game files against available media
- Finds unused or abandoned media
- Finds media that exists but is not referenced by `gamelist.xml`
- Adds valid unreferenced media to `gamelist_TEST.xml`
- Supports common RetroBat media types such as:
  - Images
  - Videos
  - Marquees
  - Fanart
  - Box art
  - Other supported media
- Helps identify and remove unwanted media interactively
- Creates and verifies a working `gamelist_TEST.xml` before promoting it to the live `gamelist.xml`, while keeping a backup of the original
- Designed for large collections

## Important

Back up your RetroBat collection before using RCCU.

RCCU is designed to work on a copy of your RetroBat `gamelist.xml` rather than directly modifying the live XML during processing.

The original:

`gamelist.xml`

is copied to:

`gamelist_TEST.xml`

RCCU performs its XML repairs and verification against the TEST XML. The original `gamelist.xml` is only backed up and replaced after final verification and user approval, unless automatic mode is enabled.

## File Recovery

RCCU does not simply permanently delete files during its cleanup operations.

On removable drives such as SD cards, RCCU uses its own:

`RCCU_RecycleBin`

Files moved there retain their original relative directory structure, allowing them to be recovered.

On fixed drives, RCCU initially uses the normal Windows Recycle Bin. If that fails, it switches to the RCCU recovery system.

RCCU also maintains a recovery log containing the original and recovered file paths.

Even with these safeguards, always maintain your own backup of important data before performing collection maintenance.

## Running RCCU

1. Download `RCCU_v4.31.ps1`.
2. Place it in the appropriate RetroBat game directory for easy directory discovery, or simply run it from anywhere.
3. Open PowerShell in that directory and run the script, run it through PowerShell ISE, or simply double-click the script.
4. Follow the instructions displayed by RCCU.

For complete information about the processing stages, matching system, XML repair, recovery system, and verification process, see `RCCU_v4.31_Documentation.txt`.

PowerShell execution policies may prevent scripts from running on some Windows installations. If Windows blocks the script, check your PowerShell execution-policy settings before proceeding.

## Project Status

RCCU is an ongoing project developed for maintaining large RetroBat collections.

Features and behavior may change between versions.

## License

RCCU is open source and released under the MIT License.

See the `LICENSE` file for the full license text.

## Extended Feature List

### 🧹 Collection Cleanup

- Scan an entire RetroBat collection recursively
- Process individual RetroBat systems/directories
- Process every `gamelist.xml` underneath a root automatically
- Find duplicate ROM/source files
- Protect the newest duplicate from deletion
- Handle `.m3u` playlists intelligently
- Handle BIN/CUE disc-image relationships
- Avoid treating disc payloads as separate games
- Identify stale XML game entries
- Identify games that exist physically but are missing from XML
- Identify duplicate XML paths
- Identify broken media references

### 🖼️ Image Cleanup

- Detect completely black images
- Detect completely white images
- Detect transparent/uniform images
- Detect solid-green images
- Analyze large images at reduced resolution for speed
- Process image analysis using multiple workers
- Detect large black borders/letterboxing
- Calculate potential crop regions
- Review detected black-bar images before changing them
- Crop selected images
- Recycle unwanted images instead of permanently deleting them, preserving directory structure

### 🎬 Video Processing

- Find videos throughout the collection
- Bulk-normalize videos with FFmpeg to avoid ES preview playback artifacting
- H.264/libx264 encoding
- AAC audio
- yuv420p
- Constant 30 FPS
- Preserve original resolution
- 160-kbps audio
- 48-kHz audio
- Preserve filenames/extensions
- Run multiple FFmpeg jobs in parallel
- Automatically calculate processing concurrency from CPU resources
- Log queued/completed/successful/failed conversions
- Reconcile normalized videos with the games and XML

### 🔗 Media to ROM Matching

- Discover physical RetroBat media
- Recognize different media categories
- Match media against actual game/source files
- Match media against XML titles
- Handle release-heavy filenames
- Handle TOSEC-style naming
- Strip known media suffixes
- Handle numbered media
- Normalize common naming differences
- Ignore punctuation differences
- Retain numbers during normalization
- Distinguish `Game 3` from `Game`
- Distinguish `Version 2.1` from `Version 21`
- Use the clean XML title as an additional matching alias
- Detect ambiguous matches
- Refuse to guess when multiple games could match
- Produce unmatched-media lists for human review
- Does not equate “unreferenced” with “useless”

### 📝 XML Repair

- Create `gamelist_TEST.xml`
- Work against the TEST XML rather than the live XML
- Remove stale game entries
- Remove broken media references
- Add missing game entries
- Add missing media references
- Resolve relative RetroBat paths correctly
- Validate XML after saving
- Use temporary XML files during writes
- Verify game-entry counts
- Reject zero-game XML
- Keep ordinary metadata from being mistaken for media paths
- Record XML changes

### ♻️ Recovery Instead of Deletion

- Windows Recycle Bin support for fixed drives
- Dedicated `RCCU_RecycleBin` for removable/SD media
- Preserve the complete original relative path
- Recovery manifest/log
- Handle duplicate recovery filenames
- Automatically fall back to RCCU recovery if Windows recycling fails
- Cache the failed recycle strategy
- Exclude the RCCU recovery folder from future scans

### 🔐 Permission Handling

- Detect current Windows user dynamically
- Check ownership/access recursively
- Repair ownership when necessary
- Grant Modify permissions
- Apply inheritance
- Recheck permissions afterward
- Refuse to proceed when required access isn't available

### 🔎 Final Verification

Before touching the real XML, RCCU checks:

- Missing game/source files
- Missing XML game entries
- Duplicate XML paths
- Broken media references
- XML integrity
- TEST XML validity

After successful verification, RCCU can:

- Back up the original XML
- Promote the verified TEST XML
- Attempt automatic restoration of the original if promotion fails

### 📊 Logging and Reporting

RCCU can generate:

- `000-Output.txt`
- `000-VerificationAudit.txt`
- `000-MediaAudit.txt`
- `000-XMLChanges.txt`
- `000-GameList.txt`
- `000-VideoNormalization.txt`

The output window provides:

- Clickable file paths
- Open file
- Open containing folder
- Highlight file
- Copy path/name
- Copy selected output text

### 🎛️ Runtime Controls

- PAUSE
- START/resume
- STOP
- START OVER
- Individual stage enable/disable

### 🤖 Automation

- Automatic “YES TO EVERYTHING”
- Automatic recursive-root processing
- Sequential processing of multiple RetroBat `gamelist.xml` directories
- Automatic cleanup decisions
- Automatic XML repair
- Automatic promotion after verification

### ⚙️ Performance

- Multi-worker image analysis
- Parallel FFmpeg processing
- Cached recovery directories
- Cached recycle strategy
- Direct .NET `File.Move()` for RCCU recovery
- De-duplicated media discovery
- Controlled XML loading/saving
- Designed for very large collections
