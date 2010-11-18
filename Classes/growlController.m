/*
//  growlController.m
//  keka
//
//  Created by aONe on 15/11/2010.
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


#import "growlController.h"
#import "kekaController.h"

@implementation growlController

#pragma mark -
#pragma mark Growl Settings

- (id) init {
    self = [super init];	
	growlAlertWaiting = 0;
	NSBundle *growlBundle = [NSBundle bundleWithPath:[[[NSBundle bundleForClass:[growlController class]] privateFrameworksPath] stringByAppendingPathComponent:@"Growl.framework"]];
	if (growlBundle && [growlBundle load]) { // Register ourselves as a Growl delegate
		[GrowlApplicationBridge setGrowlDelegate:self];
	}
	else { NSLog(@"Keka could not load Growl.framework!"); }
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(extractionComplete:) name:@"growlExtractOK" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(extractionFailed:) name:@"growlExtractFAIL" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(compressionComplete:) name:@"growlCompressOK" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(compressionFailed:) name:@"growlCompressFAIL" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(betaService:) name:@"growlBetaService" object:nil];
    return self;
}

-(int)growlNotificationsLaunched {
	return growlAlertWaiting;
}

-(BOOL)growlBlockingExit:(BOOL)Blocking {
	if ((Blocking)||(!Blocking)) growlBlockingExit = Blocking;
	return growlBlockingExit;
}

#pragma mark -
#pragma mark Growl Clicks

- (void)growlNotificationWasClicked:(id)clickContext {
	//NSLog(@"%@",clickContext);
	if ([clickContext isEqualToString:@"KekaErrorGrowl"]) {
		[NSApp activateIgnoringOtherApps:YES]; // Show error message	
	}
	else {
		[[NSWorkspace sharedWorkspace] selectFile:clickContext inFileViewerRootedAtPath:clickContext]; // Showing files extracted/compressed
	}
	growlAlertWaiting--;
	if ((growlAlertWaiting<=0)&&(growlBlockingExit)&&(![[kekaController alloc] growlExitCheck])) [NSApp terminate:self]; // Exit!
}

- (void) growlNotificationTimedOut:(id)clickContext {
	growlAlertWaiting--;
	if ((growlAlertWaiting<=0)&&(growlBlockingExit)&&(![[kekaController alloc] growlExitCheck])) [NSApp terminate:self]; // Exit!
}


#pragma mark -
#pragma mark Growl notifications

// Growl
- (NSDictionary *)registrationDictionaryForGrowl {
	NSArray *notifications = [NSArray arrayWithObjects:NSLocalizedString(@"Extraction complete",nil),NSLocalizedString(@"Extraction fail",nil),NSLocalizedString(@"Compression complete",nil),NSLocalizedString(@"Compression fail",nil),NSLocalizedString(@"Operation not implemented",nil),nil];
	return [NSDictionary dictionaryWithObjectsAndKeys:notifications, GROWL_NOTIFICATIONS_ALL, notifications, GROWL_NOTIFICATIONS_DEFAULT, nil];
}
- (void)betaService:(NSNotification *)notif {
	//[aProgressWindow makeKeyAndOrderFront:nil];
	//[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Operation not implemented",nil) description:NSLocalizedString(@"This operation is not implemented yet so Keka is in beta process.",nil) notificationName:NSLocalizedString(@"Operation not implemented",nil) iconData:[NSData dataWithData:[[NSImage imageNamed:@"keka"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}
- (void)extractionComplete:(NSNotification *)notif {
	NSLog(@"Growl path en growlC: %@",[[kekaController alloc] growlFile]);

	if ([GrowlApplicationBridge isGrowlRunning]) growlAlertWaiting++;
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Extraction complete",nil) description:[NSString stringWithFormat:NSLocalizedString(@"Extraction of file \"%@\" complete",nil),[[[kekaController alloc] growlFile] lastPathComponent]] notificationName:NSLocalizedString(@"Extraction complete",nil) iconData:[NSData dataWithData:[[NSImage imageNamed:@"keka"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:[[kekaController alloc] growlFile]];
}
- (void)extractionFailed:(NSNotification *)notif {
	if ([GrowlApplicationBridge isGrowlRunning]) growlAlertWaiting++;
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Extraction fail",nil) description:[NSString stringWithFormat:NSLocalizedString(@"Extraction of file \"%@\" failed.",nil),[[[kekaController alloc] growlFile] lastPathComponent]] notificationName:NSLocalizedString(@"Extraction fail",nil) iconData:[NSData dataWithData:[[NSImage imageNamed:@"keka"] TIFFRepresentation]] priority:1 isSticky:NO clickContext:@"KekaErrorGrowl"];
}
- (void)compressionComplete:(NSNotification *)notif {
	if ([GrowlApplicationBridge isGrowlRunning]) growlAlertWaiting++;
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Compression complete",nil) description:[NSString stringWithFormat:NSLocalizedString(@"File \"%@\" created",nil),[[[kekaController alloc] growlFile] lastPathComponent]] notificationName:NSLocalizedString(@"Compression complete",nil) iconData:[NSData dataWithData:[[NSImage imageNamed:@"keka"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:[[kekaController alloc] growlFile]];
}
- (void)compressionFailed:(NSNotification *)notif {
	if ([GrowlApplicationBridge isGrowlRunning]) growlAlertWaiting++;
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Compression fail",nil) description:[NSString stringWithFormat:NSLocalizedString(@"File \"%@\" cannot be created",nil),[[[kekaController alloc] growlFile] lastPathComponent]] notificationName:NSLocalizedString(@"Compression fail",nil) iconData:[NSData dataWithData:[[NSImage imageNamed:@"keka"] TIFFRepresentation]] priority:1 isSticky:NO clickContext:@"KekaErrorGrowl"];
}

@end
