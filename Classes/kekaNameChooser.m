/*
//  kekaNameChooser.m
//  keka
//
//  Created by aONe on 07/01/2010.
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


#import "kekaNameChooser.h"

@implementation kekaNameChooser

#pragma mark -
#pragma mark Compression Name Controller

- (NSString *)archiveNameChooser:(NSString *)Input withExtension:(NSString *)Extension filesCount:(int)FilesCount nameControlled:(BOOL)NameController defaultName:(NSString *)DefaultName splitted:(NSString *)Splitted pathController:(int)PathController {
	
	//NSLog(@"Input path: %@",Input);
	
	switch (PathController){
		case 1: { // Ask
			// Custom name and folder selected, nothing to change
		}
		break;
		case 2: { // Next to original file
			if (FilesCount > 1) {
				Input = [[[Input stringByDeletingLastPathComponent] stringByAppendingPathComponent:NSLocalizedString(@"Compressed file",nil)] stringByAppendingPathExtension:Extension];
			} else {
				if ([[NSFileManager defaultManager] contentsAtPath:Input] == 0) { Input = [Input stringByAppendingPathExtension:Extension]; }
				else { Input = [[Input stringByDeletingPathExtension] stringByAppendingPathExtension:Extension]; }
			}
		}
		break;
		case 3: { // Default folder
			if (FilesCount > 1) {
				Input = [[[Input stringByDeletingLastPathComponent] stringByAppendingPathComponent:NSLocalizedString(@"Compressed file",nil)] stringByAppendingPathExtension:Extension];
			} else {
					Input = [[Input stringByDeletingPathExtension] stringByAppendingPathExtension:Extension];
			}
		}
		break;
	}
	
	if (NameController == 2) { // If custom name is selected and not empty
		if ((DefaultName != nil) && (DefaultName.length != 0))
			Input = [[[Input stringByDeletingLastPathComponent] stringByAppendingPathComponent:DefaultName] stringByAppendingPathExtension:Extension];
	}

	// Look for existing output file, and rename if folder alredy exist
	int n=2;
	NSMutableString *locationToSaveTemp;
	
	if ((Splitted != NULL) & (Splitted != @"")) { // If split selected, output will be with 001 extension
		Input = [[[Input stringByDeletingPathExtension] stringByAppendingPathExtension:Extension] stringByAppendingPathExtension:@"001"];
		locationToSaveTemp = [[NSMutableString alloc] initWithString:Input];
		while([[NSFileManager defaultManager] fileExistsAtPath:locationToSaveTemp])
		{
			locationToSaveTemp = nil;
			locationToSaveTemp = [[NSMutableString alloc] initWithString:[[Input stringByDeletingPathExtension] stringByDeletingPathExtension]];
			[locationToSaveTemp appendString:[NSString stringWithFormat:@" %d.%@.%@",n++,Extension,@"001"]];
		}
		Input = [[NSMutableString alloc] initWithString:[locationToSaveTemp stringByDeletingPathExtension]];
	}
	
	locationToSaveTemp = [[NSMutableString alloc] initWithString:Input];
	
	while([[NSFileManager defaultManager] fileExistsAtPath:locationToSaveTemp])
	{
		locationToSaveTemp = nil;
		locationToSaveTemp = [[NSMutableString alloc] initWithString:Input];
		locationToSaveTemp = [[NSMutableString alloc] initWithString:[Input stringByDeletingPathExtension]];
		[locationToSaveTemp appendString:[NSString stringWithFormat:@" %d.%@",n++,Extension]];
	}
	
	Input = locationToSaveTemp;
	
	//NSLog(@"Output path: %@",Input);
	
	return Input;
}

#pragma mark -
#pragma mark Extraction Temporal Folder

- (NSMutableString *)extractNameChooserTemporal:(NSMutableString *)Input {
	
	NSMutableString * InputModified;
	// sopenFileDestinationPathRename = [[NSMutableString alloc] initWithString:[currentFilename stringByDeletingLastPathComponent]];
	int generated = (random() % 100) * 123;
	
	InputModified = [[NSMutableString alloc] initWithString:Input];
	[InputModified appendString:[NSString stringWithFormat:@"/.keka_temp_%d",generated]];

	// Look for existing folder, and rename if folder alredy exist
	while([[NSFileManager defaultManager] fileExistsAtPath:InputModified])
	{
		generated = (random() % 100) * 123;
		InputModified = [[NSMutableString alloc] initWithString:Input];
		[InputModified appendString:[NSString stringWithFormat:@"/.keka_temp_%d",generated]];
	}
	
	return InputModified;
}

@end
