use framework "Foundation"
use framework "AppKit"
use framework "PDFKit"
use scripting additions

property appName : "PDF Flattener"
property NSFileManager : a reference to current application's NSFileManager
property NSString : a reference to current application's NSString
property NSURL : a reference to current application's NSURL
property NSUUID : a reference to current application's NSUUID
property PDFDocument : a reference to current application's PDFDocument
property PDFView : a reference to current application's PDFView

on run
	display dialog "Drag one or more PDF files or folders onto this app. PDFs inside folders will be processed recursively." with title appName buttons {"OK"} default button "OK"
end run

on open droppedItems
	script runStats
		property succeeded : 0
		property failed : 0
		property ignored : 0
		property found : 0
		property errorText : ""
	end script

	repeat with droppedItem in droppedItems
		my processDroppedItem(droppedItem, runStats)
	end repeat

	display dialog (my summaryForStats(runStats)) with title appName buttons {"OK"} default button "OK"
end open

on processDroppedItem(droppedItem, runStats)
	set itemPath to POSIX path of (droppedItem as alias)
	set fileManager to NSFileManager's defaultManager()
	set attributes to fileManager's attributesOfItemAtPath_error_(itemPath, missing value)

	if attributes is missing value then
		set runStats's ignored to (runStats's ignored) + 1
		return
	end if

	set fileType to attributes's objectForKey_(current application's NSFileType)
	if (fileType's isEqualToString_(current application's NSFileTypeDirectory)) as boolean then
		my processFolder(itemPath, runStats)
	else if (my isPDFPath(itemPath)) then
		my processPDF(itemPath, runStats)
	else
		set runStats's ignored to (runStats's ignored) + 1
	end if
end processDroppedItem

on processFolder(folderPath, runStats)
	set folderName to ((NSString's stringWithString_(folderPath))'s lastPathComponent()'s lowercaseString()) as text
	if folderName is "flattened" then
		set runStats's ignored to (runStats's ignored) + 1
		return
	end if

	set fileManager to NSFileManager's defaultManager()
	set folderString to NSString's stringWithString_(folderPath)
	set directoryEnumerator to fileManager's enumeratorAtPath_(folderPath)

	repeat
		set relativePath to directoryEnumerator's nextObject()
		if relativePath is missing value then exit repeat

		set fullPath to (folderString's stringByAppendingPathComponent_(relativePath)) as text
		set attributes to fileManager's attributesOfItemAtPath_error_(fullPath, missing value)
		if attributes is not missing value then
			set fileType to attributes's objectForKey_(current application's NSFileType)
			if (fileType's isEqualToString_(current application's NSFileTypeDirectory)) as boolean then
				set directoryName to ((NSString's stringWithString_(fullPath))'s lastPathComponent()'s lowercaseString()) as text
				if directoryName is "flattened" then directoryEnumerator's skipDescendants()
			else if (my isPDFPath(fullPath)) then
				my processPDF(fullPath, runStats)
			end if
		end if
	end repeat
end processFolder

on isPDFPath(filePath)
	set pathExtension to ((NSString's stringWithString_(filePath))'s pathExtension()'s lowercaseString()) as text
	return pathExtension is "pdf"
end isPDFPath

on processPDF(inputPath, runStats)
	set parentName to ((NSString's stringWithString_(inputPath))'s stringByDeletingLastPathComponent()'s lastPathComponent()'s lowercaseString()) as text
	if parentName is "flattened" then
		set runStats's ignored to (runStats's ignored) + 1
		return
	end if

	set runStats's found to (runStats's found) + 1
	try
		my flattenPDFAtPath(inputPath)
		set runStats's succeeded to (runStats's succeeded) + 1
	on error errorMessage number errorNumber
		set runStats's failed to (runStats's failed) + 1
		set runStats's errorText to (runStats's errorText) & return & "- " & inputPath & ": " & errorMessage
	end try
end processPDF

on flattenPDFAtPath(inputPath)
	set fileManager to NSFileManager's defaultManager()
	set inputString to NSString's stringWithString_(inputPath)
	set parentPath to inputString's stringByDeletingLastPathComponent()
	set outputDirectory to parentPath's stringByAppendingPathComponent_("Flattened")
	set outputPath to outputDirectory's stringByAppendingPathComponent_(inputString's lastPathComponent())
	set uniqueName to ".__flattening_" & ((NSUUID's UUID()'s UUIDString()) as text) & ".pdf"
	set temporaryPath to outputDirectory's stringByAppendingPathComponent_(uniqueName)
	set temporaryURL to NSURL's fileURLWithPath_(temporaryPath)
	set outputURL to NSURL's fileURLWithPath_(outputPath)

	set madeDirectory to fileManager's createDirectoryAtPath_withIntermediateDirectories_attributes_error_(outputDirectory, true, missing value, missing value)
	if not (madeDirectory as boolean) then error "Could not create the Flattened folder."

	try
		set inputURL to NSURL's fileURLWithPath_(inputPath)
		set sourceDocument to PDFDocument's alloc()'s initWithURL_(inputURL)
		if sourceDocument is missing value then error "PDFKit could not open this PDF."

		set pageCount to sourceDocument's pageCount()
		if pageCount is 0 then error "The PDF contains no pages."

		set outputDocument to PDFDocument's alloc()'s init()
		repeat with pageIndex from 0 to (pageCount - 1)
			set sourcePage to sourceDocument's pageAtIndex_(pageIndex)
			if sourcePage is missing value then error "Could not read page " & (pageIndex + 1) & "."

			set pageBounds to sourcePage's boundsForBox_(current application's kPDFDisplayBoxMediaBox)
			set renderView to PDFView's alloc()'s initWithFrame_(pageBounds)
			try
				sourcePage's setDisplaysAnnotations_(true)
				renderView's setDocument_(sourceDocument)
				renderView's goToPage_(sourcePage)
				renderView's setDisplayBox_(current application's kPDFDisplayBoxMediaBox)
				renderView's setAutoScales_(false)
				renderView's setScaleFactor_(1.0)
				renderView's setBackgroundColor_(current application's NSColor's whiteColor())
				renderView's setDisplaysPageBreaks_(false)
				set pageData to renderView's dataWithPDFInsideRect_(renderView's |bounds|())
			on error errorMessage number errorNumber
				error errorMessage number errorNumber
			end try
			set renderedDocument to PDFDocument's alloc()'s initWithData_(pageData)
			set renderedPage to renderedDocument's pageAtIndex_(0)
			if renderedPage is missing value then error "Could not render page " & (pageIndex + 1) & "."

			outputDocument's insertPage_atIndex_(renderedPage, outputDocument's pageCount())
		end repeat

		set didWrite to outputDocument's writeToURL_(temporaryURL)
		if not (didWrite as boolean) then error "Could not write the flattened PDF."

		if (fileManager's fileExistsAtPath_(outputPath)) as boolean then
			set replacedURL to fileManager's replaceItemAtURL_withItemAtURL_backupItemName_options_resultingItemURL_error_(outputURL, temporaryURL, missing value, 0, missing value, missing value)
			if replacedURL is missing value then error "Could not replace the existing flattened PDF."
		else
			set didMove to fileManager's moveItemAtURL_toURL_error_(temporaryURL, outputURL, missing value)
			if not (didMove as boolean) then error "Could not move the flattened PDF into place."
		end if
	on error errorMessage number errorNumber
		if (fileManager's fileExistsAtPath_(temporaryPath)) as boolean then fileManager's removeItemAtURL_error_(temporaryURL, missing value)
		error errorMessage number errorNumber
	end try
end flattenPDFAtPath

on summaryForStats(runStats)
	if (runStats's found) is 0 then
		return "No PDF files were found." & return & "Ignored: " & (runStats's ignored)
	end if

	set summaryText to "Flattening complete." & return & "Succeeded: " & (runStats's succeeded) & return & "Failed: " & (runStats's failed) & return & "Ignored: " & (runStats's ignored)
	if (runStats's errorText) is not "" then set summaryText to summaryText & return & return & "Errors:" & (runStats's errorText)
	return summaryText
end summaryForStats
