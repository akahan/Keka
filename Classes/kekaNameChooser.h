/*
//  kekaNameChooser.h
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


#import <Cocoa/Cocoa.h>

@interface kekaNameChooser: NSObject {
}
- (NSString *)archiveNameChooser:(NSString *)Input withExtension:(NSString *)Extension filesCount:(int)FilesCount nameControlled:(BOOL)NameController defaultName:(NSString *)DefaultName splitted:(NSString *)Splitted pathController:(int)PathController;
- (NSMutableString *)extractNameChooserTemporal:(NSMutableString *)Input;

@end