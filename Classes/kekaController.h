/*
//  kekaController.h
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


#import <Cocoa/Cocoa.h>
#import "Growl/Growl.h"

#define PREFERENCES_FOLDER @"~/Library/Application Support/keka"	// Folder to store preferences
#define PREFERENCES_FILE @"~/Library/Application Support/keka/keka.plist"	// File to store preferences
#define PREFERENCES_FILE_VERSION @"0.1.3.2"	// Preferences file version

@interface kekaController : NSObject <GrowlApplicationBridgeDelegate>
{
	// Defaults
	BOOL chargingPreferences;				// If yes, don't modify file, just for read
	NSString *default_format;				// Default format
	NSString *default_method;				// Default method
	NSString *default_extension;			// Default extension
	int default_location_Controller;		// Default location controller
	int default_extract_location_Controller;	// Default extract location controller
	NSString *default_location;				// Default location
	NSString *default_location_set;			// Default location set by user
	NSString *default_extract_location_set;	// Default extract location set by user
	int default_name_Controller;			// Default name controller
	NSString *default_name;					// Default name
	NSString *default_name_set;				// Default name set by user
	int closeController;					// Default option to close or not when no window opened
	int defaultAutoActionController;		// Default action to do with files
	int autoActionController;				// Action to do with files	
	BOOL deleteAfterCompression;			// True for delete original file after compression
	BOOL deleteAfterExtraction;				// True for delete original file after extraction
	BOOL showFinderAfterCompression;		// True for show finder after compression
	BOOL showFinderAfterExtraction;			// True for show finder after extraction
	BOOL excludeMacForks;					// True for exclude all mac hidden forks



	// Windows
	IBOutlet NSWindow *amainWindow;
	IBOutlet NSWindow *aProgressWindow;
	IBOutlet NSWindow *PreferencesWindow;
	IBOutlet NSWindow *MainWindow;
	IBOutlet NSPanel *aPasswordWindow;
	IBOutlet NSPanel* closeAdviceWindow;
	IBOutlet NSMenu *kekaDockMenu;
	BOOL processOpened;	// Know if app is yet open
	BOOL openMainWindowAtStartUp;	// Know if app is yet open
	
	// Dock Menu
	IBOutlet NSMenuItem *kekaDockMenuPerformAuto;
	IBOutlet NSMenuItem *kekaDockMenuPerformCompress;
	IBOutlet NSMenuItem *kekaDockMenuPerformExtract;
	IBOutlet NSMenuItem *kekaDockMenuFormat7z;
	IBOutlet NSMenuItem *kekaDockMenuFormatZip;
	IBOutlet NSMenuItem *kekaDockMenuFormatTar;
	IBOutlet NSMenuItem *kekaDockMenuFormatGzip;
	IBOutlet NSMenuItem *kekaDockMenuFormatBzip2;
	IBOutlet NSMenuItem *kekaDockMenuMethodMenu;
	IBOutlet NSMenuItem *kekaDockMenuMethodStore;
	IBOutlet NSMenuItem *kekaDockMenuMethodFastest;
	IBOutlet NSMenuItem *kekaDockMenuMethodFast;
	IBOutlet NSMenuItem *kekaDockMenuMethodNormal;
	IBOutlet NSMenuItem *kekaDockMenuMethodMaximum;
	IBOutlet NSMenuItem *kekaDockMenuMethodUltra;
	BOOL kekaDockMenuMethodIvalidated;
	
	// Preferences window
    IBOutlet NSPopUpButton *default_format_pop;
	IBOutlet NSPopUpButton *default_method_pop;
	IBOutlet NSPopUpButton *default_location_pop;
	IBOutlet NSPopUpButton *default_name_pop;
	IBOutlet NSTextField *default_name_box;
	IBOutlet NSPopUpButton *default_extract_location_pop;
	IBOutlet NSButton *closeControllerCheck;
	IBOutlet NSMatrix *performAutoAction;
	IBOutlet NSButton *deleteAfterExtractionCheck;
	IBOutlet NSButton *deleteAfterCompressionCheck;
	IBOutlet NSButton *excludeMacForksCheck;
	IBOutlet NSButton *showFinderAfterExtractionCheck;
	IBOutlet NSButton *showFinderAfterCompressionCheck;
	
	// Main window
	IBOutlet NSSecureTextField *apassword;
    IBOutlet NSPopUpButton *aformat;
	IBOutlet NSPopUpButton *amethod;
	IBOutlet NSComboBox *splitSelection;
	IBOutlet NSButton *asolid;
	IBOutlet NSButton *aencrypt;
	IBOutlet NSButton *aDeleteAfterCompression;
	IBOutlet NSButton *aExcludeMacForks;

		
	// Progress Window
	IBOutlet NSProgressIndicator *aprogressMini;
	IBOutlet NSTextField *aprocessStatusText;
	IBOutlet NSTextField *aprocessTimerStatusText;
	IBOutlet NSImageView *aprocessIcon;
	IBOutlet NSButton *aStop;
	IBOutlet NSButton *pauseButton;
	
	// Password panel
	IBOutlet NSSecureTextField *passwordToExtract;
	NSMutableString *passwordToExtractArg;
	IBOutlet NSTextField *passwordNeedAdvice;
	
	// Arguments
	NSString *sformat;		// Var to save the selected format
	NSString *sextension;	// Extension to the selected format
	NSString *smethod;		// Var to save the selected method
	NSString *ssplit;		// Var to save split volumes size
	NSString *ssolid;		// Var to save the solid status
	NSString *spassword;	// Var to save the password to add
	NSString *spasswordx;	// Var to save the password to extract
	NSString *sencrypt;		// Var to save the solid status
	NSString *sopenFile;	// Var to save filename when open
	
	// Paths
	NSString *locationToSave;	// Var to store save location path to pass to binary
	NSString *nameToSave;	// Var to save file name to pass to binary
	NSMutableString *sopenFileDestinationPath;	// Var to save destination path to pass to binary
	NSMutableString *sopenFileDestinationPathRename;	// Var to save destination path
	NSMutableString *newLocation;	// Folder or file name after temporary extraction
	//NSMutableString *sprocessStatusText;		// Var to make status text in process window
	
	// Filetypes
	NSArray *allowedOpenFileTypes;	// File types that can extract
	
	// Task
	NSTask *sietezip; // task var
	NSTimer *timeCounterVar; // time counter timer
	NSTimer *tasksQueueVar; // tasks queue timer
	int actionTODO; // action selected deppending on file types dropped
	int filesToUse; // counter of files to extract
	int sietezipStatus; // task end status
	int extractCurrentFile; // var to store current file to extract
	NSArray *listOfFiles; // List of openfiles filenames
	NSArray *listOfFilesToArchive; // List of openfiles filenames
	NSMutableArray *listOfFilesToExtract;
	BOOL dragController; // YES if drag yet in use
	NSPipe *pipeOut;
	NSFileHandle *handleOut;
	NSData *dataOut;
	NSString *stringOut;
	/*NSPipe *pipeErr;
	NSFileHandle *handleErr;
	NSData *dataErr;
	NSString *stringErr;
	NSPipe *pipeIn;
	NSFileHandle *handleIn;
	NSData *dataIn;
	NSString *stringIn;*/
	BOOL passController; // YES if password if checked
	BOOL pauseController;
	BOOL deleteTarAfeterExtraction; // Check if we have some Tar to delete
	int deleteTarAfeterExtractionId; // Variable to store id of  Tar autoextracted
	
	// Time control
	NSTimer *sieteTimer; // task timer
	int seconds;
	int minutes;
	int hours;
	NSString *totalTimeString; // store the total time to show in growl
	
	// keka app control
	BOOL kekaLastExitWasOK;
	int growlAlertWaiting;
	BOOL growlBlockingExit;
}

// Main window functions
- (IBAction)DeleteFilesAfterCompressionTemporaryCheck:(id)sender;
- (IBAction)excludeMacForksMainCheck:(id)sender;
- (IBAction)seeAdvancedOptionsWindow:(id)sender;

// User preferences functions
- (void)kekaUserPreferencesCreate; // Create new preferences file
- (void)kekaUserPreferencesRead; // Read preferences file
- (void)kekaUserPreferencesModify; // Modify preferences file
- (IBAction)kekaShowUserPreferences:(id)sender; // Show preferences window
- (IBAction)kekaUserPreferencesFormat:(id)sender; // Action to do on format change
- (IBAction)kekaUserPreferencesMethod:(id)sender; // Action to do on method change
- (IBAction)kekaUserPreferencesLocation:(id)sender; // Action to do on location combo box change
- (IBAction)kekaUserPreferencesExtractLocation:(id)sender; // Action to do on extract location combo box change
- (IBAction)kekaUserPreferencesName:(id)sender; // Action to do on method change
- (IBAction)kekaUserPreferencesNameSet:(id)sender; // Action to do on method change
- (IBAction)kekaUserPreferencesCloseController:(id)sender; // Action to do on close controller
- (IBAction)kekaUserPreferencesAutoActionController:(id)sender; // Action to perform by default
- (IBAction)kekaUserPreferencesDeleteAfterCompression:(id)sender;
- (IBAction)kekaUserPreferencesDeleteAfterExtraction:(id)sender;
- (IBAction)kekaUserPreferencesShowFinderAfterCompression:(id)sender;
- (IBAction)kekaUserPreferencesShowFinderAfterExtraction:(id)sender;
- (IBAction)kekaUserExcludeMacForks:(id)sender; // Action to do when click on Mac forks check box
- (IBAction)kekaDefaultProgram:(id)sender; // Action to do when press act as default program button

// Dock Menu
- (IBAction)dockMenuFormat:(id)sender;
- (void)dockMenuFormatClean;
- (IBAction)dockMenuMethod:(id)sender;
- (void)dockMenuMethodClean;
- (void)dockMenuMethodInvalidate;
- (void)dockMenuMethodValidate;
- (IBAction)dockMenuPerformAction:(id)sender;
- (void)dockMenuPerformActionClean;

// Action of arguments
- (IBAction)actformat:(id)sender;
- (IBAction)actmethod:(id)sender;
- (IBAction)actsolid:(id)sender;
- (IBAction)actencrypt:(id)sender;
- (void)actionSplit;

// Operation controlller
- (IBAction)actstopProgressWindowAction:(id)sender;
- (IBAction)pauseProgressWindowAction:(id)sender;

// Check if all list can be extracted, if not, ationTODO is 2 to make a new archive with files
- (void)performAction;

// Things to do if need a password
-(void)passwordCheck;

// Read output and take control of it
-(void)sieteReader:(NSNotification *)notification;

// Compress function
- (void)kekaCompressFunc;

// Sending password typed by user
- (IBAction)passwordSend:(id)sender;

// Button to cancel progress from password
- (IBAction)actstopPasswordPanelAction:(id)sender;

// Extract function
- (void)kekaExtractFunc;

// Delete file partially extracted
- (void)delPartialExtract;

// Binary selection
- (void)binaryTask;

// Output argument selection deppending on filetype and binary to use
- (void)binaryOutputArgument;

// End process function
- (void)kekaEndProcess;

// Compress/uncompress progress timer
- (void)sietezipProgress:(NSTimer *)theTimer;

// Compress/uncompress time progress timer
- (void)timeCounter:(NSTimer *)theTimer;

// Drag and drop
- (BOOL)application:(NSApplication *)theApplication openFiles:(NSArray *)filenames;

// Exit functions
- (BOOL)kekaExit;
- (void)kekaSaveExitStatus;
- (IBAction)kekaExitYesResponse:(id)sender;
- (IBAction)kekaExitNoResponse:(id)sender;

// Bad shutdown restore
- (void)kekaEndAllUnClosedProccess;


- (void)set_deleteAfterCompression:(BOOL)a; //
- (BOOL)get_deleteAfterCompression; //


@end
