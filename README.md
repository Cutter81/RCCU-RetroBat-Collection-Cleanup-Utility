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

RCCU is intended to help maintain large collections, but you should always have a backup of important files before performing deletions or other changes.

Your original "gamelist.xml" should be preserved while RCCU creates the updated copy.

Requirements

- Windows
- PowerShell
- A RetroBat game collection

Usage

1. Download the ".ps1" file from this repository.
2. Place it where you want to run it, or in the appropriate RetroBat game directory.
3. Run the PowerShell script.
4. Follow the prompts displayed by RCCU.

PowerShell execution policies may prevent scripts from running on some Windows installations. If Windows blocks the script, check your PowerShell execution-policy settings before proceeding.

Project Status

RCCU is an ongoing project developed for maintaining large RetroBat collections.

Features and behavior may change between versions.

License

RCCU is open source and released under the MIT License.

See the "LICENSE" file for the full license text.
