# Babybel

[Place logo here: a Rosetta Stone or Tower of Babel-inspired symbol]

## Transcribing made easy

Babybel is a native macOS application for transcribing manuscripts and historical documents into Markdown, Word and other text formats. It combines manuscript image viewing, text editing, language reference tools and custom handwriting recognition in one workspace.

> macOS14 are the minimun requirements. 

## App UI

Babybel follows the native macOS design language, using Apple's system orange as its primary accent colour. It supports both light and dark modes.

### Splitview
The main workspace consists of two panes: a manuscript image viewer and a text editor, with Markdown as the default editing format.

Users can customise the workspace by:

1. Switching between horizontal and vertical split layouts.
2. Can have up to even 4 splitted windows for more winodws for notes or reference photos to display.
3. Resizing the panes to suit the manuscript and transcription.
4. Showing or hiding the top toolbar and bottom information bar.

### infobar
The optional bottom information bar can display:

- Line count and character count.
- Text encoding.
- Line-ending format, such as LF or CRLF.

## File

Babybel works directly with user-selected directories. When a directory is opened, the application displays supported manuscript images alongside associated text files.

Like Obsidian, Babybel keeps the user's files as ordinary files in their original directory. It does not require a proprietary project file or a separate database to access the transcription.

The aim is to make manuscript work portable, transparent and easy to back up using existing file-management tools.

## Export
Can export to Markdown (.md), Rich Text Format (.rtf), Plain text (.txt), PDF, Microsoft Word (.docx)
Export options can include password protection for PDF and Word documents, where supported by the export implementation.

## Features

1. Historical language dictionaries: Built-in or installable dictionaries support ancient languages, historical spelling and specialised vocabulary.
2. Translation and language selection. Users can select the source language of a manuscript and the target language for translation.
3. Local word lookup: Users can search for similar words across manuscript images in the currently opened directory. This helps identify recurring names, abbreviations, symbols and letter forms.
4. Online lookup to find similar words selected on the image: Users can select a word or character in a manuscript image and search online references for similar forms, spellings or possible interpretations.
5. Custom recognition models: users can train or adapt recognition models to identify the handwriting, words, symbols and letters found in their manuscript collections. 
6. Adjust Image brigthness, white temperature and contrast for easy reading.
8. The app will detect each line in the picture, put the 
7. Line by line translation mode, which the translator will translate line by line like the original transcription (press one time enter for change line) and for changing the parragraph use (cmd+enter). 
    8. When exporting the user can select the lines using [enter] to be groupped in the same line or not

## Principles

1. **Native, not web-based**. A macOS application, with standard keyboard shortcuts, native file access and system appearance settings.
2. **Open and portable**: Files remain yours. Manuscripts and transcriptions stay in ordinary folders and standard file formats.
3. **Human-guided transcription**: Recognition tools suggest possible readings, while the user remains responsible for interpreting ambiguous handwriting. Dictionary lookup, repeated-word comparison and custom recognition supports the close reading of historical documents rather than merely converting images into generic text.

## Roadmap

1. Languages & Dictionaries
    1. [ ] Spelling Check
    1. [ ] macOS dictionary support
    1. [ ] dictionaries of old languages and historical spelling.
    1. [ ] Choose language or languages at the same time to check
    1. [ ] Users can select the source language of a manuscript and the target language for translation.

1. Image Editing
    1. [ ] Adjust Image brigthness, white temperature and contrast for easy reading.

1. Image word recognition
    1. [ ] The app will detect each line in the picture, put the a focus on that line
    1. [ ] Line by line translation mode, which the translator will translate line by line like the original transcription (press one time enter for change line) and for changing the parragraph use (cmd+enter). 
        1. When exporting the user can select the lines using [enter] to be groupped in the same line or not

1. Advance
    1. [ ] Users can search for similar words across manuscript images in the currently opened directory. This helps identify recurring names, abbreviations, symbols and letter forms. 
    1. [ ] Custom recognition models: users can train or adapt recognition models to identify the handwriting, words, symbols and letters found in their manuscript collections.
