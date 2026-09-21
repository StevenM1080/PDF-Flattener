# PDF Flattener

These two drag-and-drop tools flatten saved PDF form fields while leaving the original PDFs untouched. Each output uses the original filename and is written to a `Flattened` folder beside its source PDF. Dropped folders are searched recursively, and existing `Flattened` folders are skipped.

If an output already exists, it is safely replaced only after a new flattened PDF has been created successfully.

## Windows

1. Install the current 64-bit [Ghostscript](https://ghostscript.com/releases/gsdnld.html) release if it is not already installed.
2. Drag one or more PDFs, folders, or a mixture of both onto `Flatten PDFs - Windows.cmd`.
3. Review the completion counts in the command window, then press any key to close it.

The script locates Ghostscript from `PATH` or its standard `Program Files` installation folder.

## macOS

The Mac version is native and has no third-party dependencies. It uses the PDFKit, AppKit, and Foundation frameworks included with macOS.

1. Open `Flatten PDFs - macOS.applescript` in Script Editor.
2. Choose **File > Export**, set **File Format** to **Application**, and save it as `Flatten PDFs.app`. Leave **Stay open after run handler** unchecked.
3. Drag one or more PDFs, folders, or a mixture of both onto the exported app.

As a Terminal alternative to steps 1–2, change to this folder and run `osacompile -o "Flatten PDFs.app" "Flatten PDFs - macOS.applescript"`.

The app displays completion counts and any per-file errors when it finishes.

## Notes

- Save all form entries in the source PDF before flattening it.
- Password-protected PDFs may fail unless their restrictions permit processing.
- Digital signatures will not remain valid after flattening because the PDF contents change.
- The native Mac version renders visible annotations into the page. Links and other annotations may no longer be interactive in its output.
