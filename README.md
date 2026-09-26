RCCU — RetroBat Collection Cleanup Utility

A PowerShell utility for maintaining RetroBat game collections, media files, and "gamelist.xml".

RCCU is designed to help find missing, unused, and unreferenced media in large RetroBat collections while keeping the original "gamelist.xml" safe.

Features

- Scans RetroBat game collections and their media folders
- Compares game files against available media
- Finds unused or abandoned media
- Finds media that exists but is not referenced by "gamelist.xml"
- Adds valid unreferenced media to a new XML
- Supports common RetroBat media types such as:
  - Images
  - Videos
  - Marquees
  - Fanart
  - Box art
  - Other supported media
- Helps identify and remove unwanted media interactively
- Creates a new/modified "gamelist.xml" rather than overwriting the original
- Designed for large collections

Important

Back up your RetroBat collection before using RCCU.

RCCU is designed to work on a copy of your RetroBat "gamelist.xml" rather than directly modifying the live XML during processing.

The original:

"gamelist.xml"

is copied to:

"gamelist_TEST.xml"

RCCU performs its XML repairs and verification against the TEST XML. The original "gamelist.xml" is only backed up and replaced after final verification and user approval, unless automatic mode is enabled.

File Recovery

RCCU does not simply permanently delete files during its cleanup operations.

On removable drives such as SD cards, RCCU uses its own:

"RCCU_RecycleBin"

Files moved there retain their original relative directory structure, allowing them to be recovered.

On fixed drives, RCCU initially uses the normal Windows Recycle Bin. If that fails, it switches to the RCCU recovery system.

RCCU also maintains a recovery log containing the original and recovered file paths.

Even with these safeguards, always maintain your own backup of important data before performing collection maintenance.

Download

RCCU

"RCCU_v4.29.ps1"

Documentation

"RCCU_v4.29_Documentation.txt"

The documentation contains the complete Stage 1–9 function and safety details for RCCU v4.29.

Running RCCU

1. Download "RCCU_v4.29.ps1".
2. Place it in the appropriate RetroBat game directory.
3. Open PowerShell in that directory.
4. Run the script.
5. Follow the instructions displayed by RCCU.

For complete information about the processing stages, matching system, XML repair, recovery system, and verification process, see "RCCU_v4.29_Documentation.txt".

PowerShell execution policies may prevent scripts from running on some Windows installations. If Windows blocks the script, check your PowerShell execution-policy settings before proceeding.

Project Status

RCCU is an ongoing project developed for maintaining large RetroBat collections.

Features and behavior may change between versions.

License

RCCU is open source and released under the MIT License.

See the "LICENSE" file for the full license text.
