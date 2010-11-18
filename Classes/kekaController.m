/*
//  kekaController.m
//  keka
//
//  Created by aONe on 22/07/2009.
//  Copyright © 2009-2010 aONe.
//
//  This file is part of keka.
//
//  keka is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  keka is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>
*/


#import "kekaController.h"
#import "kekaNameChooser.h"
#import "Growl/Growl.h"


@implementation kekaController



#pragma mark -
#pragma mark Start

- (id) init {
    self = [super init];
	//NSLog(@"Starting Keka...");
	dragController = NO; // var of drag set to NO as its not used yet
	passController = NO; // set to YES, when set NO passwordCheck will look for password
	processOpened = NO; // to open main if keka it's not opened dragging in it
	deleteTarAfeterExtraction = NO; // If yes, will look for Tar id file to delete it
	
	// Notification control to check outputs
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( sieteReader: ) name:NSFileHandleReadCompletionNotification object:nil];
	
	// growl
	NSBundle *myBundle = [NSBundle bundleForClass:[kekaController class]]; NSString *growlPath = [[myBundle privateFrameworksPath] stringByAppendingPathComponent:@"Growl.framework"]; NSBundle *growlBundle = [NSBundle bundleWithPath:growlPath];
	if (growlBundle && [growlBundle load]) { // Register ourselves as a Growl delegate
	[GrowlApplicationBridge setGrowlDelegate:self];
	}
	else { NSLog(@"Keka could not load Growl.framework!"); }
	growlAlertWaiting = 0;
	
		
    return self;
}

- (void)dealloc {
	[sietezip release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

// Things to do at start
- (void)awakeFromNib {
	
	// Save advanced window position
	
	/*window location and size
    NSPanel * window = (NSPanel *)[self window];
    CGFloat windowHeight = [window frame].size.height;
    [window setFrameAutosaveName: @"Advanced"];
    [window setFrameUsingName: @"Advanced"];
    NSRect windowRect = [window frame];
    windowRect.origin.y -= windowHeight - windowRect.size.height;
    windowRect.size.height = windowHeight;
    [window setFrame: windowRect display: NO];
    [window setBecomesKeyOnlyIfNeeded: YES];
	[[MainWindow windowController] setShouldCascadeWindows:NO]; // Tell the controller to not cascade its windows.
	[MainWindow setFrameAutosaveName:[MainWindow representedFilename]];
	 */
		
	// growl
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(extractionComplete:) name:@"growlExtractOK" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(extractionFailed:) name:@"growlExtractFAIL" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(compressionComplete:) name:@"growlCompressOK" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(compressionFailed:) name:@"growlCompressFAIL" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(betaService:) name:@"growlBetaService" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(multiProcess:) name:@"growlMultiProcess" object:nil];
	
	// Load preferences file or create if dont exists
	chargingPreferences = YES;
	[self kekaUserPreferencesRead];
	
	// Load all configuration in main window depending on default format
	[self actformat:nil];
	[self actmethod:nil];
	[self kekaUserPreferencesAutoActionController:nil];
	[aDeleteAfterCompression setState:deleteAfterCompression];
	[aExcludeMacForks setState:excludeMacForks];
	
	if (!kekaLastExitWasOK) [self kekaEndAllUnClosedProccess]; // If a bad keka termination succeed, clean all unclosed binaries
	[self kekaSaveExitStatus];
	
	chargingPreferences = NO;
	
	[[amainWindow windowController] setShouldCascadeWindows:NO];      // Tell the controller to not cascade its windows.
	[amainWindow setFrameAutosaveName:[amainWindow representedFilename]];
	//NSLog(@"%@",[amainWindow setFrameUsingName:[amainWindow representedFilename]]);
	//[amainWindow center];
	
	[PreferencesWindow center];
	[aProgressWindow center];

	NSLog(@"Keka ready.");
}

#pragma mark -
#pragma mark keka Restore

- (void)kekaEndAllUnClosedProccess {
	NSLog(@"Last exit was bad, cleaning Keka proccesses...");
	system("killall -SIGTERM keka7z");
	system("killall -SIGKILL keka7z");
	system("killall -SIGTERM kekaunrar");
	system("killall -SIGKILL kekaunrar");
	system("killall -SIGTERM kekaunace");
	system("killall -SIGKILL kekaunace");
}


#pragma mark -
#pragma mark Exiting
// kekaExit function, to save correct status of all done.
- (BOOL)kekaExit {
	if (processOpened == NO) {
		
		//if ((![GrowlApplicationBridge isGrowlRunning]) || (growlAlertWaiting <= 0)) {
			NSLog(@"Keka ended.");
			//NSLog(@"Keka exit: %@",[amainWindow setFrameUsingName:[amainWindow representedFilename]]);
			[self kekaSaveExitStatus];
			return YES;
		/*}
		else {
			//growlAlertWaiting--;
			growlBlockingExit = TRUE;
			NSLog(@"Waiting for Growl to exit...");
			[NSApp hide:self];
			return NO;
		}*/
	}
	else {
		if (!pauseController) [self pauseProgressWindowAction:nil];
		[NSApp beginSheet:closeAdviceWindow modalForWindow:aProgressWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
		return NO;
	}
}

- (void)kekaSaveExitStatus {
	NSMutableDictionary * prefs;
	prefs = [[NSMutableDictionary alloc] init];
	
	// Open existing file
	prefs = [NSDictionary dictionaryWithContentsOfFile: [PREFERENCES_FILE stringByExpandingTildeInPath]];
	
	if (prefs) {
		// Modify data
		if (chargingPreferences) [prefs setObject:@"0" forKey:@"ExitStatus"];
		else [prefs setObject:@"1" forKey:@"ExitStatus"];
		
		// Saving modifyed file
		BOOL success = [prefs writeToFile:[PREFERENCES_FILE stringByExpandingTildeInPath] atomically: TRUE];
		if (success == NO) {
			NSLog(@"Cannot modify preferences file!");
		}
	} else {
		NSLog(@"No user preferences file.");
    }	
}

-(IBAction)kekaExitYesResponse:(id)sender {
	//NSLog(@"Terminate process and exit...");
	[self actstopProgressWindowAction:nil];
	[self kekaSaveExitStatus];
	[NSApp terminate:self]; // Exit!
}

-(IBAction)kekaExitNoResponse:(id)sender {
	[NSApp endSheet:closeAdviceWindow]; // Close password panel
	[closeAdviceWindow orderOut:nil];
	if (pauseController) [self pauseProgressWindowAction:nil];
}

// Close the app when main window is closed
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	if (closeController == 1)
	{
		//return [self kekaExit];
		return YES;
	}
	else {
		return NO;
	}
}

// Application termination
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender {
	return [self kekaExit];
}

// Open the main window, when not just dragging a file to keka unlaunched
-(void)applicationDidFinishLaunching:(NSNotification *)notification {
	// If keka is not previously opened
	if(!processOpened)
	{
		// Show the main window
		[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
		[amainWindow makeKeyAndOrderFront:nil];
	}
}


#pragma mark -
#pragma mark Dock Menu
- (IBAction)dockMenuFormat:(id)sender {
	[aformat selectItemWithTitle:[sender title]];
	[self actformat:nil];
}

- (void)dockMenuFormatClean {
	[kekaDockMenuFormat7z setState:0];
	[kekaDockMenuFormatZip setState:0];
	[kekaDockMenuFormatTar setState:0];
	[kekaDockMenuFormatGzip setState:0];
	[kekaDockMenuFormatBzip2 setState:0];	
}

- (IBAction)dockMenuMethod:(id)sender {
	[amethod selectItemWithTitle:[sender title]];
	[self actmethod:nil];
}

- (void)dockMenuMethodClean {
	[kekaDockMenuMethodStore setState:0];
	[kekaDockMenuMethodFastest setState:0];
	[kekaDockMenuMethodFast setState:0];
	[kekaDockMenuMethodNormal setState:0];
	[kekaDockMenuMethodMaximum setState:0];
	[kekaDockMenuMethodUltra setState:0];
}

- (void)dockMenuMethodInvalidate {
	kekaDockMenuMethodIvalidated = YES;
	[kekaDockMenuMethodMenu setEnabled:NO];
}

- (void)dockMenuMethodValidate {
	if (kekaDockMenuMethodIvalidated == YES) {
		kekaDockMenuMethodIvalidated = NO;
		[kekaDockMenuMethodMenu setEnabled:YES];
	}
}

- (IBAction)dockMenuPerformAction:(id)sender {
	if ([[sender title] isEqual:NSLocalizedString(@"Perform automatic action",nil)]) {
		[performAutoAction selectCellAtRow:0 column:0];
	}
	if ([[sender title] isEqual:NSLocalizedString(@"Always compress",nil)]) {
		[performAutoAction selectCellAtRow:1 column:0];
	}
	if ([[sender title] isEqual:NSLocalizedString(@"Always extract",nil)]) {
		[performAutoAction selectCellAtRow:2 column:0];
	}
	[self kekaUserPreferencesAutoActionController:nil];
}

- (void)dockMenuPerformActionClean {
	[kekaDockMenuPerformAuto setState:0];
	[kekaDockMenuPerformCompress setState:0];
	[kekaDockMenuPerformExtract setState:0];
}



#pragma mark -
#pragma mark Default preferences

// Show preferences window
- (IBAction)kekaShowUserPreferences:(id)sender {
	//NSLog(@"Charging user preferences window...");
	chargingPreferences = YES;
	NSMutableDictionary *prefs;
	prefs = [[NSMutableDictionary alloc] init];
	
	// Open existing file
	prefs = [NSDictionary dictionaryWithContentsOfFile: [PREFERENCES_FILE stringByExpandingTildeInPath]];
	
	if (prefs) {
		int tempIndexToSelect;

		[default_format_pop selectItemWithTitle:[NSString stringWithFormat:@"%@",[prefs objectForKey:@"FormatName"]]];
		tempIndexToSelect = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultMethod"]] retain] intValue];
		[default_method_pop selectItemAtIndex:tempIndexToSelect];
		tempIndexToSelect = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultNameController"]] retain] intValue]-1;
		[default_name_pop selectItemAtIndex:tempIndexToSelect];
		tempIndexToSelect = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultSaveLocationController"]] retain] intValue]-1;
		[default_location_pop selectItemAtIndex:tempIndexToSelect];
		tempIndexToSelect = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultExtractLocationController"]] retain] intValue]-1;
		[default_extract_location_pop selectItemAtIndex:tempIndexToSelect];
		[default_name_box setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%@",nil),[prefs objectForKey:@"DefaultNameSet"]]];
		[closeControllerCheck setState:closeController];
		deleteAfterCompression = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DeleteAfterCompression"]] retain] intValue];
		deleteAfterExtraction = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DeleteAfterExtraction"]] retain] intValue];
		[deleteAfterExtractionCheck setState:deleteAfterExtraction];
		[deleteAfterCompressionCheck setState:deleteAfterCompression];
		[showFinderAfterExtractionCheck setState:showFinderAfterExtraction];
		[showFinderAfterCompressionCheck setState:showFinderAfterCompression];
		[excludeMacForksCheck setState:excludeMacForks];

		[self kekaUserPreferencesFormat:nil];
		[self kekaUserPreferencesName:nil];
		[self kekaUserPreferencesLocation:nil];
	} else {
		NSLog(@"No user preferences file.");
		[self kekaUserPreferencesCreate];
	}		
	
	chargingPreferences = NO;
	[PreferencesWindow makeKeyAndOrderFront:nil];
}

// Action to do on change format in preferences window
- (IBAction)kekaUserPreferencesFormat:(id)sender {
	
	// Arguments for each format
	switch ([default_format_pop indexOfSelectedItem])
    {
        case 0: //7Z
			default_format = @"-t7z";
			default_extension = @"7z";
			[default_method_pop setEnabled:YES]; // On 7Z, Normal method default
			break;
        case 1: // ZIP
			default_format = @"-tzip";
			default_extension = @"zip";
			[default_method_pop setEnabled:YES]; // On 7Z, Normal method default
			break;
		case 2: //TAR
			default_format = @"-ttar";
			default_extension = @"tar";
			[default_method_pop setEnabled:NO]; // On TAR, no method available
			break;
		case 3: //GZIP - single file only
			default_format = @"-tgzip";
			default_extension = @"gz";
			[default_method_pop setEnabled:YES]; // On GZIP, Normal method default
			break;
		case 4: //BZIP2  - single file only
			default_format = @"-tbzip2";
			default_extension = @"bz2";
			[default_method_pop setEnabled:YES]; // On GZIP, Normal method default
			break;
	}
	
	// Saving changes
	if (!chargingPreferences) [self kekaUserPreferencesModify];
}

// Action to do on change method in preferences window
- (IBAction)kekaUserPreferencesMethod:(id)sender {
	
	switch ([default_method_pop indexOfSelectedItem])
    {
        case 0: //STORE
			default_method = @"-mx0";
			break;
        case 1: //FASTEST
			default_method = @"-mx1";
			break;
		case 2: //FAST
			default_method = @"-mx3";
			break;
		case 3: //NORMAL
			default_method = @"-mx5";
			break;
		case 4: //MAXIMUM
			default_method = @"-mx7";
			break;
		case 5: //ULTRA
			default_method = @"-mx9";
			break;
	}
	
	// Saving changes
	if (!chargingPreferences) [self kekaUserPreferencesModify];
}

// Action to do on change default location in preferences window
- (IBAction)kekaUserPreferencesLocation:(id)sender {
	if ([[default_location_pop titleOfSelectedItem] isEqualToString: NSLocalizedString(@"Ask each time",nil)]) {
		default_location_Controller = 1;
		//default_location = [default_location_pop titleOfSelectedItem];
		[default_name_pop setEnabled:NO];
		[default_name_box setEnabled:NO];
	}
	if ([[default_location_pop titleOfSelectedItem] isEqualToString: NSLocalizedString(@"Next to original file",nil)]) {
		default_location_Controller = 2;
		//default_location = [default_location_pop titleOfSelectedItem];
		[default_name_pop setEnabled:YES];
		[default_name_box setEnabled:YES];
	}
	if ([[default_location_pop titleOfSelectedItem] isEqualToString: NSLocalizedString(@"Custom folder...",nil)]) {
		if (!chargingPreferences) {
			NSOpenPanel *folderSheet = [NSOpenPanel openPanel];
			[folderSheet setCanChooseDirectories:YES];
			[folderSheet setCanChooseFiles:NO];
			//[folderSheet beginSheetModalForWindow:PreferencesWindow completionHandler:nil];
			if ([folderSheet runModal] == NSOKButton) {
				default_location_Controller = 3;
				//default_location = [default_location_pop titleOfSelectedItem];
				default_location_set = [[folderSheet filename] retain];
				[default_name_pop setEnabled:YES];
				[default_name_box setEnabled:YES];
			} else {
				int tempIndexToSelect = default_location_Controller-1;
				[default_location_pop selectItemAtIndex:tempIndexToSelect];
			}
		}
	}
	// Saving changes
	if (!chargingPreferences) [self kekaUserPreferencesModify];
}

// Action to do on change default location in preferences window
- (IBAction)kekaUserPreferencesExtractLocation:(id)sender {
	printf("dentro");
	if ([[default_extract_location_pop titleOfSelectedItem] isEqualToString: NSLocalizedString(@"Ask each time",nil)]) {
		default_extract_location_Controller = 1;
		printf("1");
	}
	if ([[default_extract_location_pop titleOfSelectedItem] isEqualToString: NSLocalizedString(@"Next to original file",nil)]) {
		default_extract_location_Controller = 2;
		printf("2");
	}
	if ([[default_extract_location_pop titleOfSelectedItem] isEqualToString: NSLocalizedString(@"Custom folder...",nil)]) {
		printf("3");
		if (!chargingPreferences) {
			NSOpenPanel *folderSheet = [NSOpenPanel openPanel];
			[folderSheet setCanChooseDirectories:YES];
			[folderSheet setCanChooseFiles:NO];
			//[folderSheet beginSheetModalForWindow:PreferencesWindow completionHandler:nil];
			if ([folderSheet runModal] == NSOKButton) {
				default_extract_location_Controller = 3;
				default_extract_location_set = [[folderSheet filename] retain];
			} else {
				int tempIndexToSelect = default_extract_location_Controller-1;
				[default_extract_location_pop selectItemAtIndex:tempIndexToSelect];
			}
		}
	}
	// Saving changes
	if (!chargingPreferences) [self kekaUserPreferencesModify];
}

// Action to do on change default name in preferences window
- (IBAction)kekaUserPreferencesName:(id)sender {
	if ([[default_name_pop titleOfSelectedItem] isEqualToString: NSLocalizedString(@"Same as original file",nil)]) {
		default_name_Controller = 1;
		[default_name_box setEnabled:NO];
		[default_name_box setHidden:YES];
	}
	if ([[default_name_pop titleOfSelectedItem] isEqualToString: NSLocalizedString(@"Custom name...",nil)]) {
		default_name_Controller = 2;
		[default_name_box setEnabled:YES];
		[default_name_box setHidden:NO];		
	}
	// Saving changes
	if (!chargingPreferences) [self kekaUserPreferencesModify];
}

- (IBAction)kekaUserPreferencesNameSet:(id)sender {
	default_name_set = [default_name_box stringValue];
	// Saving changes
	if (!chargingPreferences) [self kekaUserPreferencesModify];
}

// Action to do on change close option
- (IBAction)kekaUserPreferencesCloseController:(id)sender {
	if ([closeControllerCheck state] == 0) closeController = 0;
	else closeController = 1;
	// Saving changes
	if (!chargingPreferences) [self kekaUserPreferencesModify];
}

// Action to do on change delete after compression option
- (IBAction)kekaUserPreferencesDeleteAfterCompression:(id)sender {
	deleteAfterCompression = [deleteAfterCompressionCheck state];
	
	// Saving changes
	if (!chargingPreferences) {
		[aDeleteAfterCompression setState:deleteAfterCompression];
		[self kekaUserPreferencesModify];
	}
}

// Action to do on change delete after extraction option
- (IBAction)kekaUserPreferencesDeleteAfterExtraction:(id)sender {
	deleteAfterExtraction = [deleteAfterExtractionCheck state];
	
	// Saving changes
	if (!chargingPreferences) [self kekaUserPreferencesModify];
}

// Action to do on change delete after extraction option
- (IBAction)kekaUserPreferencesShowFinderAfterCompression:(id)sender {
	showFinderAfterCompression = [showFinderAfterCompressionCheck state];
	
	// Saving changes
	if (!chargingPreferences) [self kekaUserPreferencesModify];
}

// Action to do on change delete after extraction option
- (IBAction)kekaUserPreferencesShowFinderAfterExtraction:(id)sender {
	showFinderAfterExtraction = [showFinderAfterExtractionCheck state];
	
	// Saving changes
	if (!chargingPreferences) [self kekaUserPreferencesModify];
}

// Action to do on change exclude mac forks option
- (IBAction)kekaUserExcludeMacForks:(id)sender {
	printf("dentro");
	excludeMacForks = [excludeMacForksCheck state];
	
	// Saving changes
	if (!chargingPreferences) {
		[aExcludeMacForks setState:excludeMacForks];
		[self kekaUserPreferencesModify];
	}
}

// Action to do on change default perform action
- (IBAction)kekaUserPreferencesAutoActionController:(id)sender {
	
	// Cleaning items in dock menu
	[self dockMenuPerformActionClean];

	if ([[[performAutoAction selectedCell] title] isEqual:NSLocalizedString(@"Perform automatic action",nil)]) {
		defaultAutoActionController = 0;
		autoActionController = 0;
		[kekaDockMenuPerformAuto setState:1];
	}
	if ([[[performAutoAction selectedCell] title] isEqual:NSLocalizedString(@"Always compress",nil)]) {
		defaultAutoActionController = 1;
		autoActionController = 1;
		[kekaDockMenuPerformCompress setState:1];
	}
	if ([[[performAutoAction selectedCell] title] isEqual:NSLocalizedString(@"Always extract",nil)]) {
		defaultAutoActionController = 2;
		autoActionController = 2;
		[kekaDockMenuPerformExtract setState:1];
	}
	// Saving changes
	if (!chargingPreferences) [self kekaUserPreferencesModify];
}

- (IBAction)kekaDefaultProgram:(id)sender {
	NSLog(@"Setting Keka as default app");

	//NSLog(@"%@",LSCopyDefaultRoleHandlerForContentType(CFSTR("org.7-zip.7-zip-archive"), kLSRolesAll));
	//NSLog(@"%@",LSCopyAllHandlersForURLScheme(CFSTR("org.7-zip.7-zip-archive")));	

	// Make keka default program to open 7Z files
	LSSetDefaultRoleHandlerForContentType(CFSTR("org.7-zip.7-zip-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open RAR files
	LSSetDefaultRoleHandlerForContentType(CFSTR("com.rarlab.rar-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open ZIP files
	LSSetDefaultRoleHandlerForContentType(CFSTR("public.zip-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	LSSetDefaultRoleHandlerForContentType(CFSTR("com.pkware.zip-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open GZIP files
	LSSetDefaultRoleHandlerForContentType(CFSTR("org.gnu.gnu-zip-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open TGZ files
	LSSetDefaultRoleHandlerForContentType(CFSTR("org.gnu.gnu-zip-tar-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open BZIP2 files
	LSSetDefaultRoleHandlerForContentType(CFSTR("public.bzip2-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	LSSetDefaultRoleHandlerForContentType(CFSTR("org.bzip.bzip2-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	LSSetDefaultRoleHandlerForContentType(CFSTR("com.redhat.bzip2-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open BZIP files
	LSSetDefaultRoleHandlerForContentType(CFSTR("public.bzip-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open TBZ2 files
	LSSetDefaultRoleHandlerForContentType(CFSTR("org.bzip.bzip2-tar-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	LSSetDefaultRoleHandlerForContentType(CFSTR("public.tar-bzip2-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open TAR files
	LSSetDefaultRoleHandlerForContentType(CFSTR("public.tar-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open LZMA files
	LSSetDefaultRoleHandlerForContentType(CFSTR("org.tukaani.lzma-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	LSSetDefaultRoleHandlerForContentType(CFSTR("public.lzma-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open ACE files
	LSSetDefaultRoleHandlerForContentType(CFSTR("com.winace.ace-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open EXE files
	LSSetDefaultRoleHandlerForContentType(CFSTR("com.microsoft.windows-executable"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open CPIO files
	LSSetDefaultRoleHandlerForContentType(CFSTR("public.cpio-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open CPGZ files
	LSSetDefaultRoleHandlerForContentType(CFSTR("com.apple.bom-compressed-cpio"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open CAB files
	LSSetDefaultRoleHandlerForContentType(CFSTR("com.microsoft.cab-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	// Make keka default program to open PAX files
	LSSetDefaultRoleHandlerForContentType(CFSTR("cx.c3.pax-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
	LSSetDefaultRoleHandlerForContentType(CFSTR("public.pax-archive"),kLSRolesAll, CFSTR("com.aone.keka"));
}

// Close Controller
- (void)kekaUserPreferencesCreate {
	//NSLog(@"Creating Keka preferences file...");
	[[NSFileManager defaultManager] createDirectoryAtPath:[PREFERENCES_FOLDER stringByExpandingTildeInPath] withIntermediateDirectories:NO attributes:nil error:nil];
	NSMutableDictionary * prefs;
	prefs = [[NSMutableDictionary alloc] init];
	
	// Default data to store
	[prefs setObject:@"0.1.3.1" forKey:@"Version"]; // Version of keka plist
    [prefs setObject:@"-tzip" forKey:@"Format"];
	[prefs setObject:@"ZIP" forKey:@"FormatName"];
	[prefs setObject:@"zip" forKey:@"Extension"];
	[prefs setObject:@"-mx5" forKey:@"Method"];
	[prefs setObject:@"3" forKey:@"DefaultMethod"];
	[prefs setObject:NSLocalizedString(@"Next to original file",nil) forKey:@"DefaultSaveLocation"];
	[prefs setObject:@"" forKey:@"DefaultSaveLocationSet"];
	[prefs setObject:@"2" forKey:@"DefaultSaveLocationController"];
	[prefs setObject:NSLocalizedString(@"Same as original file",nil) forKey:@"DefaultName"];
	[prefs setObject:@"" forKey:@"DefaultNameSet"];
	[prefs setObject:@"1" forKey:@"DefaultNameController"];
	[prefs setObject:@"2" forKey:@"DefaultExtractLocationController"];
	[prefs setObject:@"" forKey:@"DefaultExtractLocationSet"];
	[prefs setObject:@"1" forKey:@"CloseController"];
	[prefs setObject:@"0" forKey:@"DefaultActionToPerform"];
	[prefs setObject:@"1" forKey:@"ExitStatus"];	
	[prefs setObject:@"0" forKey:@"DeleteAfterCompression"];	
	[prefs setObject:@"0" forKey:@"DeleteAfterExtraction"];	
	[prefs setObject:@"0" forKey:@"FinderAfterCompression"];	
	[prefs setObject:@"0" forKey:@"FinderAfterExtraction"];	
	[prefs setObject:@"1" forKey:@"ExcludeMacForks"];	

    //[self kekaDefaultProgram:self]; // Setting keka the default app
    // Save file
    BOOL success = [prefs writeToFile:[PREFERENCES_FILE stringByExpandingTildeInPath] atomically: TRUE];
	if (success == NO) {
		NSLog(@"Cannot create preferences file!");
	} else {
		//NSLog(@"Preferences file created.");
		[self kekaUserPreferencesRead];
	}
}

// Read user preferences file
- (void)kekaUserPreferencesRead {
	//NSLog(@"Reading user preferences...");
	NSMutableDictionary * prefs;
	prefs = [[NSMutableDictionary alloc] init];

    // Open existing file
	prefs = [NSDictionary dictionaryWithContentsOfFile: [PREFERENCES_FILE stringByExpandingTildeInPath]];
	
    if (prefs) {
		NSString *actualPreferencesVersion;
		actualPreferencesVersion = [NSString stringWithFormat:@"%@",[prefs objectForKey:@"Version"]];
		if ([actualPreferencesVersion isEqual:PREFERENCES_FILE_VERSION]) {
			[aformat selectItemWithTitle:[NSString stringWithFormat:@"%@",[prefs objectForKey:@"FormatName"]]];
			int tempIndexToSelect;
			tempIndexToSelect = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultMethod"]] retain] intValue];
			[amethod selectItemAtIndex:tempIndexToSelect];
			default_format = [[NSString stringWithFormat:@"%@",[prefs objectForKey:@"Format"]] retain];
			default_extension = [[NSString stringWithFormat:@"%@",[prefs objectForKey:@"Extension"]] retain];			
			default_method = [[NSString stringWithFormat:@"%@",[prefs objectForKey:@"Method"]] retain];
			default_location_Controller = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultSaveLocationController"]] retain] intValue];
			default_location_set = [[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultSaveLocationSet"]] retain];
			default_location = [[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultSaveLocation"]] retain];
			default_name_Controller = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultNameController"]] retain] intValue];
			default_name_set = [[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultNameSet"]] retain];
			default_name = [[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultName"]] retain];
			default_extract_location_Controller = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultExtractLocationController"]] retain] intValue];
			default_extract_location_set = [[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultExtractLocationSet"]] retain];
			sformat = default_format;
			sextension = default_extension;
			smethod = default_method;
			closeController = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"CloseController"]] retain] intValue];
			defaultAutoActionController = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DefaultActionToPerform"]] retain] intValue];
			autoActionController = defaultAutoActionController;
			[performAutoAction selectCellAtRow:autoActionController column:0];	
			kekaLastExitWasOK = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"ExitStatus"]] retain] intValue];
			deleteAfterCompression = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DeleteAfterCompression"]] retain] intValue];
			deleteAfterExtraction = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"DeleteAfterExtraction"]] retain] intValue];
			showFinderAfterCompression = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"FinderAfterCompression"]] retain] intValue];
			showFinderAfterExtraction = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"FinderAfterExtraction"]] retain] intValue];
			excludeMacForks = [[[NSString stringWithFormat:@"%@",[prefs objectForKey:@"ExcludeMacForks"]] retain] intValue];
		}
		else if ([actualPreferencesVersion isEqual:@"0.1.3.1"]) { // Updating old preferences file
			NSLog(@"Updating 0.1.3.1 user preferences file...");
			[prefs setObject:@"3" forKey:@"DefaultMethod"];
			[prefs setObject:@"0.1.3.2" forKey:@"Version"];
			// Saving modifyed file
			BOOL success = [prefs writeToFile:[PREFERENCES_FILE stringByExpandingTildeInPath] atomically: TRUE];
			if (success == NO) {
				NSLog(@"Cannot modify preferences file!");
			} else {
				NSLog(@"Preferences file modifyed.");
			}
			[self kekaUserPreferencesRead];
		}
		else if ([actualPreferencesVersion isEqual:@"0.1.3"]) { // Updating old preferences file
			NSLog(@"Updating 0.1.3 user preferences file...");
			[prefs setObject:@"2" forKey:@"DefaultExtractLocationController"];
			[prefs setObject:@"0.1.3.1" forKey:@"Version"];
			// Saving modifyed file
			BOOL success = [prefs writeToFile:[PREFERENCES_FILE stringByExpandingTildeInPath] atomically: TRUE];
			if (success == NO) {
				NSLog(@"Cannot modify preferences file!");
			} else {
				NSLog(@"Preferences file modifyed.");
			}
			[self kekaUserPreferencesRead];
		}
		else if ([actualPreferencesVersion isEqual:@"0.1.2"]) { // Updating old preferences file
			NSLog(@"Updating 0.1.2 user preferences file...");
			[prefs setObject:@"1" forKey:@"ExcludeMacForks"];
			[prefs setObject:@"0" forKey:@"FinderAfterCompression"];	
			[prefs setObject:@"0" forKey:@"FinderAfterExtraction"];
			[prefs setObject:@"2" forKey:@"DefaultExtractLocationController"];
			[prefs setObject:@"" forKey:@"DefaultExtractLocationSet"];
			[prefs setObject:@"0.1.3" forKey:@"Version"];
			// Saving modifyed file
			BOOL success = [prefs writeToFile:[PREFERENCES_FILE stringByExpandingTildeInPath] atomically: TRUE];
			if (success == NO) {
				NSLog(@"Cannot modify preferences file!");
			} else {
				NSLog(@"Preferences file modifyed.");
			}
			[self kekaUserPreferencesRead];
		}
		else if ([actualPreferencesVersion isEqual:@"0.1b2"]) { // Updating old preferences file
			NSLog(@"Updating 0.1b2 user preferences file...");
			[prefs setObject:@"1" forKey:@"ExcludeMacForks"];
			[prefs setObject:@"0" forKey:@"FinderAfterCompression"];	
			[prefs setObject:@"0" forKey:@"FinderAfterExtraction"];
			[prefs setObject:@"2" forKey:@"DefaultExtractLocationController"];
			[prefs setObject:@"" forKey:@"DefaultExtractLocationSet"];
			[prefs setObject:@"0" forKey:@"DeleteAfterCompression"];	
			[prefs setObject:@"0" forKey:@"DeleteAfterExtraction"];
			[prefs setObject:@"0.1.2" forKey:@"Version"];
			// Saving modifyed file
			BOOL success = [prefs writeToFile:[PREFERENCES_FILE stringByExpandingTildeInPath] atomically: TRUE];
			if (success == NO) {
				NSLog(@"Cannot modify preferences file!");
			} else {
				NSLog(@"Preferences file modifyed.");
			}
			[self kekaUserPreferencesRead];
		}
		else if ([actualPreferencesVersion isEqual:@"0.1b"]) { // Updating old preferences file
			NSLog(@"Updating 0.1b user preferences file...");
			[prefs setObject:@"1" forKey:@"ExcludeMacForks"];
			[prefs setObject:@"0" forKey:@"FinderAfterCompression"];	
			[prefs setObject:@"0" forKey:@"FinderAfterExtraction"];
			[prefs setObject:@"2" forKey:@"DefaultExtractLocationController"];
			[prefs setObject:@"" forKey:@"DefaultExtractLocationSet"];
			[prefs setObject:@"0" forKey:@"DeleteAfterCompression"];	
			[prefs setObject:@"0" forKey:@"DeleteAfterExtraction"];
			[prefs setObject:@"1" forKey:@"CloseController"];
			[prefs setObject:@"0" forKey:@"DefaultActionToPerform"];
			[prefs setObject:@"1" forKey:@"ExitStatus"];
			[prefs setObject:@"0.1b2" forKey:@"Version"];
			// Saving modifyed file
			BOOL success = [prefs writeToFile:[PREFERENCES_FILE stringByExpandingTildeInPath] atomically: TRUE];
			if (success == NO) {
				NSLog(@"Cannot modify preferences file!");
			} else {
				NSLog(@"Preferences file modifyed.");
			}
			[self kekaUserPreferencesRead];
		}
		else { // Bad file? Create a new one
			NSLog(@"Wrong user preferences version...");
			NSLog(@"%@",[NSString stringWithFormat:@"%@",[prefs objectForKey:@"Version"]]);
			//[self kekaUserPreferencesCreate];
		}
    } else {
		NSLog(@"No user preferences file.");
		[self kekaUserPreferencesCreate];
    }
}

// Modidy preferences file
- (void)kekaUserPreferencesModify {
	//NSLog(@"Modifying user preferences...");
	NSMutableDictionary * prefs;
	prefs = [[NSMutableDictionary alloc] init];
	
	// Open existing file
	prefs = [NSDictionary dictionaryWithContentsOfFile: [PREFERENCES_FILE stringByExpandingTildeInPath]];
	
	if (prefs) {
		// Modify data
		[prefs setObject:default_extension forKey:@"Extension"];
		[prefs setObject:default_format forKey:@"Format"];
		[prefs setObject:[NSString stringWithFormat:@"%@",[default_format_pop titleOfSelectedItem]] forKey:@"FormatName"];
		[prefs setObject:default_method forKey:@"Method"];
		[prefs setObject:[NSString stringWithFormat:@"%d",[default_method_pop indexOfSelectedItem]] forKey:@"DefaultMethod"];
		[prefs setObject:[NSString stringWithFormat:@"%@",[default_location_pop titleOfSelectedItem]] forKey:@"DefaultSaveLocation"];
		[prefs setObject:default_location_set forKey:@"DefaultSaveLocationSet"];
		[prefs setObject:[NSString stringWithFormat:@"%d",default_location_Controller] forKey:@"DefaultSaveLocationController"];
		[prefs setObject:[NSString stringWithFormat:@"%d",default_extract_location_Controller] forKey:@"DefaultExtractLocationController"];
		[prefs setObject:default_extract_location_set forKey:@"DefaultExtractLocationSet"];
		[prefs setObject:[NSString stringWithFormat:@"%@",[default_name_pop titleOfSelectedItem]] forKey:@"DefaultName"];
		[prefs setObject:default_name_set forKey:@"DefaultNameSet"];
		[prefs setObject:[NSString stringWithFormat:@"%d",default_name_Controller] forKey:@"DefaultNameController"];
		[prefs setObject:[NSString stringWithFormat:@"%d",closeController] forKey:@"CloseController"];
		[prefs setObject:[NSString stringWithFormat:@"%d",defaultAutoActionController] forKey:@"DefaultActionToPerform"];
		[prefs setObject:[NSString stringWithFormat:@"%d",[deleteAfterCompressionCheck state]] forKey:@"DeleteAfterCompression"];
		[prefs setObject:[NSString stringWithFormat:@"%d",[deleteAfterExtractionCheck state]] forKey:@"DeleteAfterExtraction"];
		[prefs setObject:[NSString stringWithFormat:@"%d",[showFinderAfterCompressionCheck state]] forKey:@"FinderAfterCompression"];
		[prefs setObject:[NSString stringWithFormat:@"%d",[showFinderAfterExtractionCheck state]] forKey:@"FinderAfterExtraction"];
		[prefs setObject:[NSString stringWithFormat:@"%d",[excludeMacForksCheck state]] forKey:@"ExcludeMacForks"];
		
		// Saving modifyed file
		BOOL success = [prefs writeToFile:[PREFERENCES_FILE stringByExpandingTildeInPath] atomically: TRUE];
		if (success == NO) {
			NSLog(@"Cannot modify preferences file!");
		} else {
			//NSLog(@"Preferences file modifyed.");
		}
	} else {
		NSLog(@"No user preferences file.");
    }
}


#pragma mark -
#pragma mark Main menu button actions

// Choosing Format from Combo box
- (IBAction)actformat:(id)sender {
	
	// Cleaning format selection in dock menu
	[self dockMenuFormatClean];
		
	// Just 7z uses solid, so if not, disable the solid check & mark variable ssolid as nothing
	if ([aformat indexOfSelectedItem] == 0){
		[asolid setEnabled:YES]; // On 7Z solid archive can be created
		ssolid = @"-ms=on";
	}else{
		[asolid setEnabled:NO];
		ssolid = @"";
	}
	
	// If TAR format choosed before, select default method
	if (smethod == @"") {
		smethod = @"-mx5"; 
	}
	
	// Arguments for each format
	switch ([aformat indexOfSelectedItem])
    {
        case 0: //7Z
			sformat = @"-t7z";
			sextension = @"7z";
			[amethod setEnabled:YES]; // On 7Z, Normal method default
			[self dockMenuMethodValidate];
			[apassword setEnabled:YES];
			[aencrypt setEnabled:YES];
			[kekaDockMenuFormat7z setState:1];
			break;
        case 1: // ZIP
			sformat = @"-tzip";
			sextension = @"zip";
			[amethod setEnabled:YES]; // On 7Z, Normal method default
			[self dockMenuMethodValidate];
			[apassword setEnabled:YES];
			[aencrypt setEnabled:NO];
			sencrypt = @"";
			[kekaDockMenuFormatZip setState:1];
			break;
		case 2: //TAR
			sformat = @"-ttar";
			sextension = @"tar";
			[amethod setEnabled:NO]; // On TAR, no method available
			[self dockMenuMethodInvalidate];
			smethod = @"";
			[apassword setEnabled:NO];
			spassword = @"";
			[aencrypt setEnabled:NO];
			sencrypt = @"";
			[kekaDockMenuFormatTar setState:1];
			break;
		case 3: //GZIP - single file only
			sformat = @"-tgzip";
			sextension = @"gz";
			[amethod setEnabled:YES]; // On GZIP, Normal method default
			[self dockMenuMethodValidate];
			[apassword setEnabled:NO];
			spassword = @"";
			[aencrypt setEnabled:NO];
			sencrypt = @"";
			[kekaDockMenuFormatGzip setState:1];
			break;
		case 4: //BZIP2  - single file only
			sformat = @"-tbzip2";
			sextension = @"bz2";
			[amethod setEnabled:YES]; // On GZIP, Normal method default
			[self dockMenuMethodValidate];
			[apassword setEnabled:NO];
			spassword = @"";
			[aencrypt setEnabled:NO];
			sencrypt = @"";
			[kekaDockMenuFormatBzip2 setState:1];
			break;
	}	
	
	//NSLog(@"Format %@, command %@, output extension %@",[aformat title],sformat,sextension);
}

// Split Combo box action
- (void)actionSplit {
	
	if ([[splitSelection stringValue] isEqual:@""]) {
		ssplit = @"";
	}
	else if ([[splitSelection stringValue] isEqual:NSLocalizedString(@"1.4 MB Floppy",nil)]) {
		ssplit = @"-v1474560b";
	}
	else if ([[splitSelection stringValue] isEqual:NSLocalizedString(@"650 MB CD",nil)]) {
		ssplit = @"-v650m";
	}	
	else if ([[splitSelection stringValue] isEqual:NSLocalizedString(@"700 MB CD",nil)]) {
		ssplit = @"-v700m";
	}	
	else if ([[splitSelection stringValue] isEqual:NSLocalizedString(@"4480 MB DVD",nil)]) {
		ssplit = @"-v4480m";
	}
	else { // User edited
		NSString *tempSize;
		ssplit = NULL;
		if ([[[splitSelection stringValue] lowercaseString] rangeOfString:@"m"].length > 0) { tempSize = @"m"; } // size in MB
		else if ([[[splitSelection stringValue] lowercaseString] rangeOfString:@"k"].length > 0) { tempSize = @"k"; } // size in KB
		else if ([[[splitSelection stringValue] lowercaseString] rangeOfString:@"b"].length > 0) { tempSize = @"b"; } // size in bytes
		else if ([[[splitSelection stringValue] lowercaseString] rangeOfString:@"g"].length > 0) { tempSize = @"g"; } // size in GB
		else { tempSize = @"m"; } // default size in megas

		if ([splitSelection integerValue] > 0) {
			ssplit = [[NSString stringWithFormat:@"-v%d%@",[splitSelection integerValue],tempSize] retain];
		}
	}

	//NSLog(@"Split %@",ssplit);
	
}

// Encrypt check box action
- (IBAction)actencrypt:(id)sender {
	
	if ([aencrypt state] == 0) sencrypt = @"";
	else sencrypt = @"-mhe";
	
	//NSLog(@"Encrypt state %d, command %@",[aencrypt state],sencrypt);
	
}

// Solid check box action
- (IBAction)actsolid:(id)sender {
	
	if ([asolid state] == 0) ssolid = @"-ms=off";
	else ssolid = @"-ms=on";
	
	//NSLog(@"Solid state %d, command %@",[asolid state],ssolid);
	
}

// Choosing the Method
- (IBAction)actmethod:(id)sender {
	
	// Cleaning format selection in dock menu
	[self dockMenuMethodClean];
	
	switch ([amethod indexOfSelectedItem])
    {
        case 0: //STORE
			smethod = @"-mx0";
			[kekaDockMenuMethodStore setState:1];
			break;
        case 1: //FASTEST
			smethod = @"-mx1";
			[kekaDockMenuMethodFastest setState:1];
			break;
		case 2: //FAST
			smethod = @"-mx3";
			[kekaDockMenuMethodFast setState:1];
			break;
		case 3: //NORMAL
			smethod = @"-mx5";
			[kekaDockMenuMethodNormal setState:1];
			break;
		case 4: //MAXIMUM
			smethod = @"-mx7";
			[kekaDockMenuMethodMaximum setState:1];
			break;
		case 5: //ULTRA
			smethod = @"-mx9";
			[kekaDockMenuMethodUltra setState:1];
			break;
	}	
	//NSLog(@"Method %@, command %@",[amethod title],smethod);
}

- (IBAction)DeleteFilesAfterCompressionTemporaryCheck:(id)sender {
	deleteAfterCompression = [aDeleteAfterCompression state];
}

// Mac Forks check on main window (advanced)
- (IBAction)excludeMacForksMainCheck:(id)sender {
	excludeMacForks = [aExcludeMacForks state];
}


#pragma mark -
#pragma mark Task controller

// Progress timer
- (void)sietezipProgress:(NSTimer *)theTimer {
	//NSLog(@"siete timer running");

	if ([sietezip isRunning]) { // while running, counting
	}
	else { // on the end, close task and unshow window
		[self kekaEndProcess]; // call keka end process function
	}
}

// End process
-(void)kekaEndProcess {
	if ([sieteTimer isValid]) {
		[sieteTimer invalidate]; // stop secconds timer
	}
	if ([timeCounterVar isValid]) {
		[timeCounterVar invalidate]; // stop secconds timer
	}	
	// Saving status
	sietezipStatus = (sietezipStatus + [sietezip terminationStatus]);
	
	// disable password check process
	passController = NO;
	
	// if cancel is pressed, do nothing
	if (actionTODO != 0)
	{
		// Rename temporal folder or get out of it
		if (actionTODO == 1) {
			
			NSFileManager *fileManager = [NSFileManager defaultManager];
			NSArray *items = [fileManager contentsOfDirectoryAtPath:sopenFileDestinationPathRename error:nil];
			
			int countingFiles = [items count];
			
			// Looking if this is the Tar file autoextracted to delete the source
			if (deleteTarAfeterExtraction) {
				if (deleteTarAfeterExtractionId == extractCurrentFile) {
					[[NSFileManager defaultManager] removeItemAtPath:sopenFile error:nil]; // Delete temporal folder
					deleteTarAfeterExtraction = NO;
				}
			}

			if (countingFiles == 1) { // Just one file/folder, then delete temporary folder
				NSMutableString *newTempLocation;
				NSMutableString *actualLocation;
				NSString *temporaryFolder;
				
				temporaryFolder = sopenFileDestinationPathRename;

				actualLocation = [[NSMutableString alloc] initWithString:temporaryFolder];
				[actualLocation appendString:@"/"];
				[actualLocation appendString:[items objectAtIndex:0]];
				
				newLocation = [[NSMutableString alloc] initWithString:[temporaryFolder stringByDeletingLastPathComponent]];
				[newLocation appendString:@"/"];
				[newLocation appendString:[items objectAtIndex:0]];
				
				// Look for existing folder, and rename if folder alredy exist
				int n=2;
				newTempLocation = newLocation;
				while([fileManager fileExistsAtPath:newTempLocation])
				{
					newTempLocation = nil;

					//if ([[NSFileManager defaultManager] contentsAtPath:newLocation] == 0) {  newTempLocation = [[NSMutableString alloc] initWithString:newLocation]; }
					//else { newTempLocation = [[NSMutableString alloc] initWithString:[newLocation stringByDeletingPathExtension]]; }
					newTempLocation = [[NSMutableString alloc] initWithString:[newLocation stringByDeletingPathExtension]];
					
					//newTempLocation = [[NSMutableString alloc] initWithString:[newLocation stringByDeletingPathExtension]]; 
					
					[newTempLocation appendString:[NSString stringWithFormat:@" %d",n++]];	
					
					//if ([[NSFileManager defaultManager] contentsAtPath:newLocation] != 0) {
						if (([newLocation pathExtension] != nil) && ([newLocation pathExtension].length != 0)) { // If there is some path extension, put it
							[newTempLocation appendString:@"."];
							[newTempLocation appendString:[newLocation pathExtension]];
						}
					//}
				}
				newLocation = newTempLocation;
				
				// Looking for some Tar inside the file
				if ([[[newLocation pathExtension] lowercaseString] isEqualToString:@"tar"]) {
					NSLog(@"Tar file found... Added to queue.");
					filesToUse++;
					[listOfFilesToExtract addObject:newLocation];
					deleteTarAfeterExtraction = YES;
					deleteTarAfeterExtractionId = filesToUse-1;
				}
				[fileManager moveItemAtPath:actualLocation toPath:newLocation error:nil]; // Moving content
				// Verifying temporary folder is now empty
				NSArray *items = [fileManager contentsOfDirectoryAtPath:temporaryFolder error:nil];
				int countingFiles = [items count];
				if (countingFiles == 0) [[NSFileManager defaultManager] removeItemAtPath:temporaryFolder error:nil]; // Delete temporal folder if empty
				else [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[temporaryFolder stringByDeletingLastPathComponent] destination:nil files:[NSArray arrayWithObject:[temporaryFolder lastPathComponent]] tag:nil]; // Move to trash if any file inside... kind of string error/mistake!
				sopenFileDestinationPathRename = newLocation; // Now new location is the correct path
			}
			else { // Make folder visible deleting the initial . at the name
				NSMutableString *newTempLocation;
				NSString *temporaryFolder;
				temporaryFolder = sopenFileDestinationPathRename;
				newLocation = [[NSMutableString alloc] initWithString:[[sopenFileDestinationPathRename stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[sopenFile lastPathComponent] stringByDeletingPathExtension]]];
				
				// Look for existing folder, and rename if folder alredy exist
				int n=2;
				newTempLocation = newLocation;
				while([[NSFileManager defaultManager] fileExistsAtPath:newTempLocation])
				{
					newTempLocation = nil;
					newTempLocation = [[NSMutableString alloc] initWithString:newLocation];
					[newTempLocation appendString:[NSString stringWithFormat:@" %d",n++]];
				}
				newLocation = newTempLocation;
				[fileManager moveItemAtPath:temporaryFolder toPath:newLocation error:nil]; // Changing folder name
				sopenFileDestinationPathRename = newLocation; // Now new location is the correct path
			}

		}
		
		// 7za Error codes
		if (sietezipStatus == 0)
		{
			NSLog(@"Done without errors");
			
			// Acctions to do after work is done, deppending on operation 1 or 2.
			if (actionTODO == 1) { 
				if (deleteAfterExtraction == 1) { // Delete original file after extraction 1
					NSLog(@"Auto-deleting extracted file");
					//[[NSFileManager defaultManager] removeItemAtPath:sopenFile error:nil]; // Full delete
					
					NSString *extdelete; // Variable to store extension in lowercase
					extdelete = [[sopenFile pathExtension] lowercaseString];
					if ([extdelete isEqual:@"001"]) { // If parted file, delete all parts
						int countVolumes = 1;
						int stopDeletingVolumes = 0;
						while (stopDeletingVolumes < 1) {
							NSLog(@"deleting a volume");
							BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:sopenFile];
							NSLog(@"Existe: %d",fileExists);
							if (fileExists) {
								[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[sopenFile stringByDeletingLastPathComponent] destination:nil files:[NSArray arrayWithObject:[sopenFile lastPathComponent]] tag:nil];
								sopenFile = NULL;
								countVolumes++;
							}
							else {
								stopDeletingVolumes = 1;
							}
						}
					}
					if (([extdelete isEqual:@"r00"]) || ([extdelete isEqual:@"c00"])) { // If parted file, delete all parts
						int countVolumes = 0;
						int stopDeletingVolumes = 0;
						while (countVolumes < 1) {
							NSLog(@"deleting a volume");
							NSFileManager *fm = [NSFileManager defaultManager];
							BOOL fileExists = [fm fileExistsAtPath:sopenFile];
							NSLog(@"Existe: %d",fileExists);
							if (fileExists) {
								[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[sopenFile stringByDeletingLastPathComponent] destination:nil files:[NSArray arrayWithObject:[sopenFile lastPathComponent]] tag:nil];
								sopenFile = NULL;
								countVolumes++;
							}
							else {
								stopDeletingVolumes = 1;
							}
						}
					}
					else {
						[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[sopenFile stringByDeletingLastPathComponent] destination:nil files:[NSArray arrayWithObject:[sopenFile lastPathComponent]] tag:nil];
						sopenFile = NULL;
					}
				}
				[[NSNotificationCenter defaultCenter] postNotificationName:@"growlExtractOK" object:nil]; // Show growl message
				if (showFinderAfterExtraction == 1) [[NSWorkspace sharedWorkspace] selectFile:sopenFileDestinationPathRename inFileViewerRootedAtPath:sopenFileDestinationPathRename]; // Showing files extracted
				
			}
			else if (actionTODO == 2) {
				if (deleteAfterCompression == 1) { // Delete original file/s after compressed
					NSLog(@"Auto-deleting drooped file/s");
					int i;
					for( i = 0; i < filesToUse; i++ )
					{
						[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[[listOfFilesToArchive objectAtIndex:i] stringByDeletingLastPathComponent] destination:nil files:[NSArray arrayWithObject:[[listOfFilesToArchive objectAtIndex:i] lastPathComponent]] tag:nil];
						//[[NSFileManager defaultManager] removeItemAtPath:[listOfFilesToArchive objectAtIndex:i] error:nil]; // Full delete
					}
					[listOfFilesToArchive release];
					filesToUse = 0;
				}
				[[NSNotificationCenter defaultCenter] postNotificationName:@"growlCompressOK" object:nil]; // Show growl message
				if (showFinderAfterCompression == 1) [[NSWorkspace sharedWorkspace] selectFile:locationToSave inFileViewerRootedAtPath:[locationToSave stringByDeletingLastPathComponent]]; // Showing files created
			}
		}
		else
		{
			NSLog(@"Error code %d",sietezipStatus);
			if (actionTODO == 1)
			{
				[self delPartialExtract]; // Delete partial file
				[[NSNotificationCenter defaultCenter] postNotificationName:@"growlExtractFAIL" object:nil];
			}
			else { [[NSNotificationCenter defaultCenter] postNotificationName:@"growlCompressFAIL" object:nil]; }
		}
	}	
	
	extractCurrentFile++; // choosing next file
	
	if (extractCurrentFile < filesToUse) // cheking if files in queue
	{
		NSLog(@"Queue in action");
		[self kekaExtractFunc]; // calling extraction function again
	}
	else // no more actions to do
	{
		//NSLog(@"No more actions to do");
		
		
		if (sietezipStatus == 0) {
		dragController = NO; // drag & drop ready again

		// Stoping status bar
		[aprogressMini stopAnimation:self];
		
		// Close process window, and if is the only window, it will close keka
		processOpened = NO;
		[aProgressWindow orderOut:nil];

		// Default keka icon in progress window
		NSImage *icon = [NSImage imageNamed:@"keka"];
		[icon setSize:[aprocessIcon frame].size];
		[aprocessIcon setImage:icon];
		}
		else { // Showing error alert in process window
			NSImage *icon = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns",sextension]];
			[icon setSize:[aprocessIcon frame].size];
			[aprocessIcon setImage:icon];
			[aprogressMini stopAnimation:self];
			[aprogressMini setHidden:YES];
			[aprocessStatusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Operation failed",nil),nil]];
			[aprocessStatusText setTextColor:[NSColor redColor]];
			[aprocessTimerStatusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Operation failed with error code %d",nil),sietezipStatus]];
			[pauseButton setHidden:YES];
		}

	}
}

// Time progress timer
- (void)timeCounter:(NSTimer *)theTimer {
	//NSLog(@"timeCounter running...");
	NSString* zeroSec;
	NSString* zeroMin;
	if (seconds == 60)
	{
		minutes = (minutes + 1);
		seconds = 0;
	}
	if (minutes == 60)
	{
		hours = (hours + 1);
		minutes = 0;
	}
	if ((seconds <= 59) && (minutes == 0) && (hours == 0))
	{ 
		[aprocessTimerStatusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Time elapsed: %d seconds",nil),seconds]];
		//totalTimeString = [NSString stringWithFormat:NSLocalizedString(@"%d seconds",nil),seconds];
	}
	if ((minutes > 0) && (hours == 0))
	{
		if (seconds < 10) zeroSec = @"0";
		else zeroSec = @"";
		[aprocessTimerStatusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Time elapsed: %d:%@%d minutes",nil),minutes,zeroSec,seconds]];
		//totalTimeString = [NSString stringWithFormat:NSLocalizedString(@"%d:%@%d minutes",nil),minutes,zeroSec,seconds];
	}
	if (hours > 0)
	{
		if (seconds < 10) zeroSec = @"0";
		else zeroSec = @"";
		if (minutes < 10) zeroMin = @"0";
		else zeroMin = @"";
		[aprocessTimerStatusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Time elapsed: %d:%@%d:%@%d hours",nil),hours,zeroMin,minutes,zeroSec,seconds]];
		//totalTimeString = [NSString stringWithFormat:NSLocalizedString(@"%d:%@%d:%@%d hours",nil),hours,zeroMin,minutes,zeroSec,seconds];
	}
	seconds = seconds + 1;
}

// Reading task output
-(void)sieteReader:(NSNotification *)notification {	
	// Reading output
	dataOut = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
	stringOut = [[NSString alloc] initWithData:dataOut encoding:NSASCIIStringEncoding];
	
	
	
	/*if ([stringOut rangeOfString:@" ("].length > 0)
	 NSLog(@"pakopill %@",stringOut);
	 
	 if ([stringOut rangeOfString:@"Compressing"].length > 0)
	 {
	 NSLog(@"tanto");
	 //NSString *currentTimeString = [[stringOut componentsSeparatedByString:@"   "] componentsSeparatedByString:@"%"];
	 //NSLog(@"tanto por ciento ace %@",currentTimeString);
	 }
	 
	 if ([stringOut rangeOfString:@" "].length > 0)
	 {
	 NSLog(stringOut);
	 NSString *currentTimeString = [[[[stringOut componentsSeparatedByString:@" "] objectAtIndex:1] componentsSeparatedByString:@"%"] objectAtIndex:0];
	 NSLog(@"tanto por ciento rar %@",currentTimeString);
	 }*/
	
	
	
	if (passController = YES) // password check
	{
		if ([stringOut rangeOfString:@"Enter password"].length > 0)
		{
			NSLog(@"Password needed");
			passController = NO; // no more need to check for password
			[self passwordCheck];
		}
	}
	
	[stringOut release];
	
	if ([sietezip isRunning])
		[handleOut readInBackgroundAndNotify];
}


#pragma mark -
#pragma mark Password controller

// if password needed found, terminate task and ask for password
-(void)passwordCheck {		
	[sieteTimer invalidate];
	[timeCounterVar invalidate];
	[sietezip terminate];
	[passwordNeedAdvice setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Password needed on file \"%@\"",nil),[[listOfFilesToExtract objectAtIndex:extractCurrentFile] lastPathComponent]]];
	[NSApp beginSheet:aPasswordWindow modalForWindow:aProgressWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}

// Choosing Format from Combo box
- (IBAction)passwordSend:(id)sender {
	[NSApp endSheet:aPasswordWindow]; // Close password panel
	[aPasswordWindow orderOut:nil];
	spasswordx = [@"-p" stringByAppendingString:[passwordToExtract stringValue]]; // Save password
	[passwordToExtract setStringValue:@""]; // Reset password in the combo
	sietezip = [[NSTask alloc] init];
	pipeOut = [[NSPipe alloc] init];
	if ([[[[listOfFilesToExtract objectAtIndex:extractCurrentFile] pathExtension] lowercaseString] isEqual:@"rar"])
		[sietezip setStandardError:pipeOut]; // UNRAR uses error for password ask
	else
		[sietezip setStandardOutput:pipeOut];
	handleOut=[pipeOut fileHandleForReading];
	[handleOut readInBackgroundAndNotify];
	[self binaryTask]; 	// Choosing binary deppending on format to extract
	[sietezip setArguments:[NSArray arrayWithObjects:@"x",sopenFile,sopenFileDestinationPath,@"-y",spasswordx,nil]];
	[sietezip launch];
	[spasswordx release];
	sieteTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(sietezipProgress:) userInfo:nil repeats:YES];
	timeCounterVar = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timeCounter:) userInfo:nil repeats:YES];	
}


#pragma mark -
#pragma mark Drag and Drop controller

// Drag file to app icon
-(BOOL)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames {
	if (dragController == NO) // beta, just one progress at once
	{
		// No more actions
		dragController = YES;
				
		// Open Process Window and set as the main. Show on center
		[aprocessStatusText setStringValue:NSLocalizedString(@"Performing operation...",nil)];
		[aprocessTimerStatusText setStringValue:NSLocalizedString(@"Waiting...",nil)];
		processOpened = YES;
		[aProgressWindow makeKeyAndOrderFront:nil];
		//[aprogressMini setControlSize:SmallControlSize];
		[aprogressMini startAnimation:self];
		
		// Var to store the type of action selected deppending on extensions. Default 1, extraction
		sietezipStatus=0; // status 0, no errors
		
		filesToUse = [filenames count];
		//NSLog(@"%d",filesToUse);
		listOfFiles = filenames;
		//NSLog(@"%@",listOfFiles);
		
		locationToSave = [filenames objectAtIndex:0];

		// Loop through all the files and process them.
		[self performAction];
		
		
		// Looking for file extension. Then trying to extract or compress
		if (actionTODO == 1) // extract
		{
			NSLog(@"Extraction performed");
			
			// Performig list of files
			extractCurrentFile = 0;
			
			[listOfFilesToExtract release];
			listOfFilesToExtract = [[NSMutableArray alloc] init];
			int i;
			for( i = 0; i < filesToUse; i++ ) { // store filenames to extract
				[listOfFilesToExtract addObject:[filenames objectAtIndex:i]];
			}
			[aProgressWindow orderFront:nil]; // Showing progress window
			[self kekaExtractFunc];
		} // extraction by extension finished
		
		// if extension not allowed, compressing the file
		else
		{
			
			NSLog(@"Compression performed");
			
			kekaNameChooser* NameChooserObj = [[kekaNameChooser alloc] init];

			// Calling compress function
			listOfFilesToArchive = filenames; // storing files to add
			[aProgressWindow orderFront:nil]; // Showing progress window
			
			// Choosing output folder and name
			switch (default_location_Controller){
				case 1: { // Ask
					// Save panel, choosing destination of the new file
					NSSavePanel *saveSheet = [NSSavePanel savePanel];	
					if ([saveSheet runModal] == NSOKButton) {
						locationToSave = [[[saveSheet filename] stringByAppendingPathExtension:sextension] retain];
						locationToSave = [NameChooserObj archiveNameChooser:locationToSave withExtension:sextension filesCount:filesToUse nameControlled:0 defaultName:nil splitted:ssplit pathController:default_location_Controller];
						[self kekaCompressFunc];
					} else { // on cancel button press
						NSLog(@"Cancelled by user");
						actionTODO = 0; // Nothing
						dragController = NO; // drag & drop ready again
						processOpened = NO;
						
						[aprogressMini stopAnimation:self]; // Stoping status bar
						[aProgressWindow orderOut:nil]; // Close process window, and if is the only window, it will close keka
						
						// Default keka icon in progress window
						NSImage *icon = [NSImage imageNamed:@"keka"];
						[icon setSize:[aprocessIcon frame].size];
						[aprocessIcon setImage:icon];
					}
				}
				break;
				case 2: { // Next to original file
					locationToSave = [NameChooserObj archiveNameChooser:locationToSave withExtension:sextension filesCount:filesToUse nameControlled:default_name_Controller defaultName:default_name_set splitted:ssplit pathController:default_location_Controller];
					[self kekaCompressFunc];
				}
				break;
				case 3: { // Default folder
					if (filesToUse > 1) {
						locationToSave = [default_location_set stringByAppendingPathComponent:[NSLocalizedString(@"Compressed file",nil) stringByAppendingPathExtension:sextension]];
					} else {
						if ([[NSFileManager defaultManager] contentsAtPath:locationToSave] == 0) { locationToSave = [locationToSave stringByAppendingPathExtension:sextension]; }
						else { locationToSave = [[locationToSave stringByDeletingPathExtension] stringByAppendingPathExtension:sextension]; }
						locationToSave = [default_location_set stringByAppendingPathComponent:[locationToSave lastPathComponent]];
					}
					locationToSave = [NameChooserObj archiveNameChooser:locationToSave withExtension:sextension filesCount:filesToUse nameControlled:default_name_Controller defaultName:default_name_set splitted:ssplit pathController:default_location_Controller];
					[self kekaCompressFunc];
				}
				break;
			}
			
			[NameChooserObj release];
			
		} // end of else
	}
	else // beta, just one progress at once
	{
		[aProgressWindow orderFront:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlBetaService" object:nil];
	}		
	return YES;
} // drop function terminate

// Check if all list can be extracted, if not, ationTODO is 2 to make a new archive with files
- (void)performAction {
	
	switch (autoActionController)
    {
        case 0: { // Automatic action
			actionTODO = 1; // extract by default
			
			int i;
			for( i = 0; i < filesToUse; i++ )
			{
				NSString *extdrop; 		// Variable to store extension in lowercase
				extdrop = [[[listOfFiles objectAtIndex:i] pathExtension] lowercaseString];
				
				if (([extdrop isEqual:@"7z"]) || ([extdrop isEqual:@"001"]) || ([extdrop isEqual:@"r00"]) || ([extdrop isEqual:@"c00"]) || ([extdrop isEqual:@"zip"]) || ([extdrop isEqual:@"tar"]) || ([extdrop isEqual:@"gz"]) || ([extdrop isEqual:@"tgz"]) || ([extdrop isEqual:@"bz2"]) || ([extdrop isEqual:@"tbz2"]) || ([extdrop isEqual:@"tbz"]) || ([extdrop isEqual:@"cpgz"]) || ([extdrop isEqual:@"cpio"]) || ([extdrop isEqual:@"cab"]) || ([extdrop isEqual:@"rar"]) || ([extdrop isEqual:@"ace"]) || ([extdrop isEqual:@"lzma"]) || ([extdrop isEqual:@"pax"]) || ([extdrop isEqual:@"xz"]))
				{}
				else
				{
					actionTODO = 2; // compress
				}
			}
		}
			break;
        case 1: // Always compress
			actionTODO = 2;
			break;
		case 2: // Always extract
			actionTODO = 1;
			break;
	}
}


#pragma mark -
#pragma mark Compress/Extract

// Compress function
-(void)kekaCompressFunc {
	
	// Testing all the arguments fon none at null
	if (sformat == NULL) sformat = @"-t7z";
	if (sextension == NULL) sextension = @"7z";
	if (smethod == NULL) smethod = @"-mx5";
	[self actionSplit];
	if (ssolid == NULL) ssolid = @"-ms=on";
	spassword = [@"-p" stringByAppendingString:[apassword stringValue]];
	if (spassword == @"-p") spassword = @"";
	if (sencrypt == NULL) sencrypt = @"";
	
	// Compress call
	//NSLog(@"Format: %@",sformat);
	//NSLog(@"Command: %@",sextension);
	//NSLog(@"Method %@",smethod);
	//NSLog(@"Solid state %d, command %@",[asolid state],ssolid);
	//NSLog(@"Encrypt state %d, command %@",[aencrypt state],sencrypt);
	//NSLog(@"Password %@, command %@",[apassword stringValue],spassword);
	//NSLog(@"Split: %@",ssplit);
		
	// Showing status text
	[aprocessStatusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Creating %@ file...",nil),sextension]];
	
	// Show file icon
	NSImage* icon;
	if (sextension == @"7z") icon = [NSImage imageNamed:sextension];
	else icon = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithFormat:@"/System/Library/CoreServices/Archive Utility.app/Contents/Resources/bah-%@.icns",sextension]];
	[icon setSize:[aprocessIcon frame].size];
	[aprocessIcon setImage:icon];
	
	// Updating status text
	if ([[locationToSave lastPathComponent] length] > 23) {
		[aprocessStatusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Creating file \"%@...\"",nil),[[locationToSave lastPathComponent] substringToIndex:23]]];
	}
	else {
		[aprocessStatusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Creating file \"%@\"",nil),[locationToSave lastPathComponent]]];
	}
	
	// Calling 7za
	sietezip = [[NSTask alloc] init];
	pipeOut = [[NSPipe alloc] init];
	[sietezip setStandardOutput:pipeOut];
	handleOut=[pipeOut fileHandleForReading];
	[handleOut readInBackgroundAndNotify];
	
	[sietezip setLaunchPath:[[NSBundle mainBundle] pathForResource:@"keka7z" ofType:@""]];
	
	// Setting arguments
	NSMutableArray *sietezipCompArgs = [NSMutableArray array];
	
	[sietezipCompArgs addObject:@"a"];
	[sietezipCompArgs addObject:sformat];
	if (ssplit) [sietezipCompArgs addObject:ssplit];
	[sietezipCompArgs addObject:locationToSave];
	//[sietezipCompArgs addObject:[[locationToSave stringByDeletingPathExtension] stringByAppendingPathExtension:sextension]];
	
	// Creating list of files to add
	
	int i; // bucle for var

	for( i = 0; i < filesToUse; i++ )
	{
		// Getting current filename
		[sietezipCompArgs addObject:[listOfFilesToArchive objectAtIndex:i]];
	}
	
	if (deleteAfterCompression == 1) // If delete after compress selected, retaining list of archives
		[listOfFilesToArchive retain];
	else // No more need to files count
		filesToUse = 0;
	
	// Last arguments
	//[sietezipCompArgs addObject:@"-scc"]; // case sentitive on
	[sietezipCompArgs addObject:smethod];
	[sietezipCompArgs addObject:ssolid];
	[sietezipCompArgs addObject:spassword];
	[sietezipCompArgs addObject:sencrypt];
	
	// exclude mac forks
	if (excludeMacForks == 1) { // excluding mac hidden files
		[sietezipCompArgs addObject:@"-xr!.DS_Store"];
		[sietezipCompArgs addObject:@"-xr!.localized"];
		[sietezipCompArgs addObject:@"-xr!._*"];
		[sietezipCompArgs addObject:@"-xr!.FBC*"];
		[sietezipCompArgs addObject:@"-xr!.Spotlight-V100"];
		[sietezipCompArgs addObject:@"-xr!.Trash"];
		[sietezipCompArgs addObject:@"-xr!.Trashes"];
		[sietezipCompArgs addObject:@"-xr!.background"];
		[sietezipCompArgs addObject:@"-xr!.TemporaryItems"];
		[sietezipCompArgs addObject:@"-xr!.fseventsd"];
		[sietezipCompArgs addObject:@"-xr!.com.apple.timemachine.*"];
		[sietezipCompArgs addObject:@"-xr!.VolumeIcon.icns"];
	}
	
	// Assign argument to task
	[sietezip setArguments:sietezipCompArgs];
	//NSLog(@"%@",sietezipCompArgs);
	
	// Do Compress/Extract action
	[sietezip launch];
	
	// Launching timer to control the process
	seconds = 1;
	minutes = 0;
	hours = 0;
	timeCounterVar = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timeCounter:) userInfo:nil repeats:YES];
	sieteTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(sietezipProgress:) userInfo:nil repeats:YES];
} // Compress function end

// Extract function
-(void)kekaExtractFunc {
	
	NSLog(@"Extracting file number %d",extractCurrentFile);

	// Getting current filename
	NSString *currentFilename = [listOfFilesToExtract objectAtIndex:extractCurrentFile];
		
	// Showing status text
	if ([[currentFilename lastPathComponent] length] > 24) {
		[aprocessStatusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Extracting \"%@...\"",nil),[[currentFilename lastPathComponent] substringToIndex:24]]];
	}
	else {
		[aprocessStatusText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Extracting \"%@\"",nil),[currentFilename lastPathComponent]]];
	}

	// Show file icon
	NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:currentFilename];
	[icon setSize:[aprocessIcon frame].size];
	[aprocessIcon setImage:icon];
	
	sopenFile = currentFilename;
	
	// Choosing output folder and name
	switch (default_extract_location_Controller) {
		case 1: { // Ask
			// Save panel, choosing destination of the new file
			NSOpenPanel *openSheet = [NSOpenPanel openPanel];
			[openSheet setCanChooseDirectories:YES];
			[openSheet setCanChooseFiles:NO];
			if ([openSheet runModal] == NSOKButton) {
				sopenFileDestinationPathRename = [[NSMutableString alloc] initWithString:[[openSheet filename] retain]];
			} else { // on cancel button press
				NSLog(@"Cancelled by user");
				actionTODO = 0; // Nothing
				dragController = NO; // drag & drop ready again
				processOpened = NO;
				
				// Stoping status bar
				[aprogressMini stopAnimation:self];
				
				// Close process window, and if is the only window, it will close keka
				[aProgressWindow orderOut:nil];
				
				// Default keka icon in progress window
				NSImage *icon = [NSImage imageNamed:@"keka"];
				[icon setSize:[aprocessIcon frame].size];
				[aprocessIcon setImage:icon];
				return; // get out of extract function
			}
		} break;
		case 2: { // Next to original file
				sopenFileDestinationPathRename = [[NSMutableString alloc] initWithString:[currentFilename stringByDeletingLastPathComponent]];
		} break;
		case 3: { // Default folder
			sopenFileDestinationPathRename = [[NSMutableString alloc] initWithString:default_extract_location_set];
		} break;
	}
		
	// Temporal folder
	kekaNameChooser* NameChooserObj = [[kekaNameChooser alloc] init];
	sopenFileDestinationPathRename = [[NSMutableString alloc] initWithString:[NameChooserObj extractNameChooserTemporal:sopenFileDestinationPathRename]];
	[NameChooserObj release];
		
	// Calling 7za
	sietezip = [[NSTask alloc] init];
	pipeOut = [[NSPipe alloc] init];
	
	[self binaryTask]; 	// Choosing binary deppending on format to extract
	
	[self binaryOutputArgument]; // choose the output argument deppending on extension and binary to use
	
	if ([[[sietezip launchPath] lastPathComponent] isEqual:@"kekaunrar"]) {
		//NSLog(@"unrar");
		[sietezip setStandardError:pipeOut]; // UNRAR uses error for password ask
	}
	else
		[sietezip setStandardOutput:pipeOut];

	handleOut=[pipeOut fileHandleForReading];
	[handleOut readInBackgroundAndNotify];
	
	

	// Extract call, unrar, gnutar or 7za
	//[sietezip setArguments:[NSArray arrayWithObjects:@"x",sopenFile,sopenFileDestinationPath,@"-aou",nil]];
	NSMutableArray *sietezipExtArgs = [NSMutableArray array];
	// Case of tar, tbz or tgz
	if ([[sietezip launchPath] isEqual:@"/usr/bin/gnutar"]) {  // gnutar
		
		// Create temp folder, as gnutar does not create it automatically
		NSFileManager *fileManager = [NSFileManager defaultManager];
		[fileManager createDirectoryAtPath:sopenFileDestinationPathRename withIntermediateDirectories:YES attributes:nil error:nil];
		
		[sietezipExtArgs addObject:@"-C"];
		[sietezipExtArgs addObject:sopenFileDestinationPath];
		[sietezipExtArgs addObject:@"-xf"];
		[sietezipExtArgs addObject:sopenFile];
		[sietezipExtArgs addObject:@"--exclude=__MACOSX"];
	}
	else { // 7za
		[sietezipExtArgs addObject:@"x"];
		[sietezipExtArgs addObject:sopenFile];
		[sietezipExtArgs addObject:sopenFileDestinationPath];
		[sietezipExtArgs addObject:@"-aou"];
		[sietezipExtArgs addObject:@"-xr!__MACOSX"];
	}
	
	// Assign argument to task
	[sietezip setArguments:sietezipExtArgs];
	//NSLog(@"%@",sietezipExtArgs);
	
	// release currentFilename
	[currentFilename release];
	
	passController = YES; // check for password need
	
	// Do Compress/Extract action
	[sietezip launch];

	// Launching timer to control the process
	seconds = 1;
	minutes = 0;
	hours = 0;
	timeCounterVar = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timeCounter:) userInfo:nil repeats:YES];	
	sieteTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(sietezipProgress:) userInfo:nil repeats:YES];
}


#pragma mark -
#pragma mark Binary controller

// Output argument selection deppending on filetype and binary to use
- (void)binaryOutputArgument {
	// Choosing output argument deppending on binary
	if ([[[sietezip launchPath] lastPathComponent] isEqual:@"kekaunrar"]) // unrar
	{
		sopenFileDestinationPath = [[NSMutableString alloc] initWithString:sopenFileDestinationPathRename];
		[sopenFileDestinationPath appendString:@"/"];
	}
	else if ([[[sietezip launchPath] lastPathComponent] isEqual:@"kekaunace"]) // unace
	{
		sopenFileDestinationPath = [[NSMutableString alloc] initWithString:sopenFileDestinationPathRename];
		[sopenFileDestinationPath appendString:@"/"];
	}
	else if ([[[sietezip launchPath] lastPathComponent] isEqual:@"gnutar"]) // untar
	{
		sopenFileDestinationPath = [[NSMutableString alloc] initWithString:sopenFileDestinationPathRename];
		[sopenFileDestinationPath appendString:@"/"];
	}
	else // 7za
	{
		sopenFileDestinationPath = [[NSMutableString alloc] initWithString:@"-o"];
		[sopenFileDestinationPath appendString:sopenFileDestinationPathRename];
	}
}

// Binary selection
- (void)binaryTask {
	// unrar
	if ([[[[listOfFilesToExtract objectAtIndex:extractCurrentFile] pathExtension] lowercaseString] isEqual:@"rar"])
	{ 
		NSLog(@"Using unrar");
		[sietezip setLaunchPath:[[NSBundle mainBundle] pathForResource:@"kekaunrar" ofType:@""]];
	}
	// unace
	else if ([[[[listOfFilesToExtract objectAtIndex:extractCurrentFile] pathExtension] lowercaseString] isEqual:@"ace"])
	{
		NSLog(@"Using unace");
		[sietezip setLaunchPath:[[NSBundle mainBundle] pathForResource:@"kekaunace" ofType:@""]];
	}
	// gnutar
	else if (([[[[listOfFilesToExtract objectAtIndex:extractCurrentFile] pathExtension] lowercaseString] isEqual:@"tar"]) || ([[[[listOfFilesToExtract objectAtIndex:extractCurrentFile] pathExtension] lowercaseString] isEqual:@"tbz"]) || ([[[[listOfFilesToExtract objectAtIndex:extractCurrentFile] pathExtension] lowercaseString] isEqual:@"tgz"]))
	{	
		NSLog(@"Using gnutar");
		[sietezip setLaunchPath:@"/usr/bin/gnutar"];
	}
	// 7za
	else
	{
		NSLog(@"Using p7zip");
		[sietezip setLaunchPath:[[NSBundle mainBundle] pathForResource:@"keka7z" ofType:@""]];
	}
}


#pragma mark -
#pragma mark Action Pause

- (IBAction)pauseProgressWindowAction:(id)sender {

	if (!pauseController) {
	// if ([[pauseButton title] isEqualToString:NSLocalizedString(@"Pause",nil)]) {
		NSLog(@"Paused");
		pauseController = YES;
		[sietezip suspend];
		[aprogressMini stopAnimation:self];
		[sieteTimer invalidate];
		[timeCounterVar invalidate];
		[aprocessTimerStatusText setStringValue:NSLocalizedString(@"Operation paused",nil)];
		[pauseButton setImage:[NSImage imageNamed:@"continue"]];
		//[pauseButton setTitle:NSLocalizedString(@"Continue",nil)];
	}
	else {
		NSLog(@"Resumming...");
		pauseController = NO;
		[sietezip resume];
		[aprogressMini startAnimation:self];
		[self timeCounter:nil];
		sieteTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(sietezipProgress:) userInfo:nil repeats:YES];
		timeCounterVar = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timeCounter:) userInfo:nil repeats:YES];
		[pauseButton setImage:[NSImage imageNamed:@"pause"]];
		//[pauseButton setTitle:NSLocalizedString(@"Pause",nil)];
	}	
}


#pragma mark -
#pragma mark Action stop

// Delete file partially extracted
- (void)delPartialExtract {
	if (actionTODO == 1)
	{
		[[NSFileManager defaultManager] removeItemAtPath:sopenFileDestinationPathRename error:nil];
	}
	
}

// Button to cancel progress
- (IBAction)actstopProgressWindowAction:(id)sender {
	
	// Stop process
	if (pauseController == YES) {
		[sietezip resume];
		[pauseButton setImage:[NSImage imageNamed:@"pause"]];
		//[pauseButton setTitle:NSLocalizedString(@"Pause",nil)];
	}
	else if ([[aprocessStatusText textColor] isEqual:[NSColor redColor]]){
		[aprogressMini setHidden:NO];
		[aprocessStatusText setTextColor:[NSColor blackColor]];
		[pauseButton setHidden:NO];
		//[aStop setTitle:NSLocalizedString(@"Cancel",nil)];
	}
	else {
		[sieteTimer invalidate];
		[timeCounterVar invalidate];
		[aprogressMini stopAnimation:self]; // Pausing mini progress bar
	}


	// terminate bucle in queue
	filesToUse = 0;
	
	// terminate task
	[sietezip terminate];
	
	// Delete partial file
	[self delPartialExtract];
	
	// Close process window, and if is the only window, it will close keka
	processOpened = NO;
	[aProgressWindow orderOut:nil];	
	
	// Pause button to default state
	
	
	// Default keka icon in progress window
	NSImage *icon = [NSImage imageNamed:@"keka"];
	[icon setSize:[aprocessIcon frame].size];
	[aprocessIcon setImage:icon];
	
	dragController = NO; // drag & drop ready again
	passController = NO; // enable password check
	
	NSLog(@"Operation stoped");
}

// Button to cancel progress from password
- (IBAction)actstopPasswordPanelAction:(id)sender {
	// Hide password panel
	[NSApp endSheet:aPasswordWindow];
	[aPasswordWindow orderOut:nil];	

	// Reset password in the combo
	[passwordToExtract setStringValue:@""];
	
	// terminate bucle in queue
	filesToUse = 0;
	
	// terminate task
	//[sietezip terminate];
	
	// Delete partial file
	[self delPartialExtract];
	
	// Stoping status bar
	if (pauseController == NO) {
		[aprogressMini stopAnimation:self]; // Pausing mini progress bar
	}
	
	// Close process window, and if is the only window, it will close keka
	processOpened = NO;
	[aProgressWindow orderOut:nil];	
	
	// Default keka icon in progress window
	NSImage *icon = [NSImage imageNamed:@"keka"];
	[icon setSize:[aprocessIcon frame].size];
	[aprocessIcon setImage:icon];
	
	dragController = NO; // drag & drop ready again
	passController = NO; // enable password check
	
	NSLog(@"Operation stoped");
}


#pragma mark -
#pragma mark Growl notifications

// Growl
- (NSDictionary *)registrationDictionaryForGrowl {
	NSArray *notifications = [NSArray arrayWithObjects:NSLocalizedString(@"Extraction complete",nil),NSLocalizedString(@"Extraction fail",nil),NSLocalizedString(@"Compression complete",nil),NSLocalizedString(@"Compression fail",nil),NSLocalizedString(@"Operation not implemented",nil),nil];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:notifications, GROWL_NOTIFICATIONS_ALL, notifications, GROWL_NOTIFICATIONS_DEFAULT, nil];
}
- (void)betaService:(NSNotification *)notif {
	[aProgressWindow makeKeyAndOrderFront:nil];
	//[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Operation not implemented",nil) description:NSLocalizedString(@"This operation is not implemented yet so Keka is in beta process.",nil) notificationName:NSLocalizedString(@"Operation not implemented",nil) iconData:[NSData dataWithData:[[NSImage imageNamed:@"keka"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}
- (void)extractionComplete:(NSNotification *)notif {
	if ([GrowlApplicationBridge isGrowlRunning]) growlAlertWaiting++;
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Extraction complete",nil) description:[NSString stringWithFormat:NSLocalizedString(@"Extraction of file \"%@\" complete",nil),[[listOfFilesToExtract objectAtIndex:extractCurrentFile] lastPathComponent]] notificationName:NSLocalizedString(@"Extraction complete",nil) iconData:[NSData dataWithData:[[NSImage imageNamed:@"keka"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:newLocation];
}
- (void)extractionFailed:(NSNotification *)notif {
	if ([GrowlApplicationBridge isGrowlRunning]) growlAlertWaiting++;
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Extraction fail",nil) description:[NSString stringWithFormat:NSLocalizedString(@"Extraction of file \"%@\" failed.",nil),[[listOfFilesToExtract objectAtIndex:extractCurrentFile] lastPathComponent]] notificationName:NSLocalizedString(@"Extraction fail",nil) iconData:[NSData dataWithData:[[NSImage imageNamed:@"keka"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:[listOfFilesToExtract objectAtIndex:extractCurrentFile]];
}
- (void)compressionComplete:(NSNotification *)notif {
	if ([GrowlApplicationBridge isGrowlRunning]) growlAlertWaiting++;
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Compression complete",nil) description:[NSString stringWithFormat:NSLocalizedString(@"File \"%@\" created",nil),[locationToSave lastPathComponent]] notificationName:NSLocalizedString(@"Compression complete",nil) iconData:[NSData dataWithData:[[NSImage imageNamed:@"keka"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:locationToSave];
}
- (void)compressionFailed:(NSNotification *)notif {
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Compression fail",nil) description:[NSString stringWithFormat:NSLocalizedString(@"File \"%@\" cannot be created",nil),[locationToSave lastPathComponent]] notificationName:NSLocalizedString(@"Compression fail",nil) iconData:[NSData dataWithData:[[NSImage imageNamed:@"keka"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}
- (void)growlNotificationWasClicked:(id)clickContext {
	[[NSWorkspace sharedWorkspace] selectFile:clickContext inFileViewerRootedAtPath:clickContext]; // Showing files extracted
	if ([GrowlApplicationBridge isGrowlRunning]) growlAlertWaiting--;
	if (growlAlertWaiting <= 0) {
		if (growlBlockingExit) {
			if (processOpened == NO) {
				growlBlockingExit = FALSE;
				//NSLog(@"Growl sending exit");
				[NSApp terminate:self]; // Exit!
			}
		}
	}
}
- (void) growlNotificationTimedOut:(id)clickContext {
	growlAlertWaiting--;
	if (growlAlertWaiting <= 0) {
		if (growlBlockingExit) {
			if (processOpened == NO) {
				growlBlockingExit = FALSE;
				//NSLog(@"Growl sending exit");
				[NSApp terminate:self]; // Exit!
			}
		}
	}
}



#pragma mark -
#pragma mark Testing
- (IBAction)seeAdvancedOptionsWindow:(id)sender {
	[NSApp beginSheet:amainWindow modalForWindow:MainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}


- (void)set_deleteAfterCompression:(BOOL)a {
	deleteAfterCompression = a;
}

- (BOOL)get_deleteAfterCompression {
	return deleteAfterCompression;
}


@end
