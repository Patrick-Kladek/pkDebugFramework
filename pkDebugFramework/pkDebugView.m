//
//  pkDebugView.m
//  pkDebugFramework
//
//  Created by Patrick Kladek on 21.05.15.
//  Copyright (c) 2015 Patrick Kladek. All rights reserved.
//

// TODO: calculate hight of labels and resize ...

#import "pkDebugView.h"
#import <objc/runtime.h>
#import "pkDebugSettings.h"
#import "pkPropertyEnumerator.h"


@interface pkDebugView ()
{
	NSInteger pos;
	NSInteger leftWidth;
	NSInteger rightWidth;
	
	NSTextField *titleTextField;
	
	
	pkPropertyEnumerator *propertyEnumerator;
}

- (void)_addLineWithDescription:(NSString *)desc string:(NSString *)value leftColor:(NSColor *)leftColor rightColor:(NSColor *)rightColor leftFont:(NSFont *)lFont rightFont:(NSFont *)rfont;

@end



@implementation pkDebugView


+ (pkDebugView *)debugView
{
	pkDebugView *view = [[pkDebugView alloc] init];
	return view;
}

+ (NSData *)getSubData:(NSData *)source withRange:(NSRange)range
{
	UInt8 bytes[range.length];
	[source getBytes:&bytes range:range];
	NSData *result = [[NSData alloc] initWithBytes:bytes length:sizeof(bytes)];
	return result;
}

+ (pkDebugView *)debugViewWithAllPropertiesOfObject:(NSObject *)obj includeSubclasses:(BOOL)include
{
	pkDebugView *view = [[pkDebugView alloc] init];
	[view setObj:obj];
	
	if (include) {
		[view traceSuperClassesOfObject:obj];
	} else {
		[view setTitle:[obj className]];
	}
	
	[view addAllPropertiesFromObject:obj includeSubclasses:include];
	
	if ([view save]) {
		[view saveDebugView];
	}

	return view;
}

+ (pkDebugView *)debugViewWithProperties:(NSString *)properties ofObject:(NSObject *)obj
{
	pkDebugView *view = [[pkDebugView alloc] init];
	[view setObj:obj];
	
	[view traceSuperClassesOfObject:obj];
	[view addProperties:properties fromObject:obj];
	
	if ([view save]) {
		[view saveDebugView];
	}
	
	return view;
}






- (instancetype)init
{
	self = [super init];
	if (self)
	{
		pkDebugSettings *settings = [pkDebugSettings sharedSettings];
		
		self.lineSpace				= settings.lineSpace;
		self.highlightKeywords		= settings.highlightKeywords;
		self.highlightNumbers		= settings.highlightNumbers;
		
		self.textColor				= settings.textColor;
		self.textFont				= settings.textFont;
		
		self.keywordColor			= settings.keywordColor;
		self.keywordFont			= settings.keywordFont;
		
		self.numberColor			= settings.numberColor;
		self.numberFont				= settings.numberFont;
		
		self.propertyNameColor		= settings.propertyNameColor;
		self.propertyNameFont		= settings.propertyNameFont;
		
		self.titleColor				= settings.titleColor;
		self.titleFont				= settings.titleFont;
		
		self.backgroundColor		= settings.backgroundColor;
		self.frameColor				= settings.frameColor;
		
		self.imageSize				= settings.imageSize;
		self.convertDataToImage		= settings.convertDataToImage;
		self.propertyNameContains	= [NSMutableArray arrayWithArray:[settings propertyNameContains]];
		
		self.save 					= settings.save;
		self.saveUrl				= settings.saveUrl;
		self.saveAsPDF				= settings.saveAsPDF;
		
		self.dateFormat				= settings.dateFormat;
	
		
		
		
		propertyEnumerator = [[pkPropertyEnumerator alloc] init];
		
		
		leftWidth				= 0;
		rightWidth				= 0;
		pos						= 30;
		_title					= @"pkDebugView";
		[self setTitle:_title];
		
		
		
		
		self.layer = _layer;
		self.wantsLayer = YES;
		self.layer.masksToBounds = YES;
		
		[self.layer setBackgroundColor:[_backgroundColor CGColor]];
	}
	return self;
}

- (void)setDefaultsFromUrl:(NSURL *)url
{
	if (![url isFileURL]) {
		return;
	}
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
	// TODO: change this
	if (titleTextField.frame.size.width + 20 > self.frame.size.width)	// +20 => | 10 --- label ----- 10 |
	{
		[self setFrame:NSMakeRect(self.frame.origin.x, self.frame.origin.y, titleTextField.frame.size.width + 20, self.frame.size.height)];
	}
	
	[self setWantsLayer:YES];
	[self.layer setCornerRadius:5];
	[self.layer setBorderColor:[_frameColor CGColor]];
	[self.layer setBorderWidth:1];
	[self setLayer:self.layer];
	
	[self.layer setBackgroundColor:[_backgroundColor CGColor]];
	
	NSRect rect = NSMakeRect(0, 0, dirtyRect.size.width, 23);
//	[_frameColor set];
//	NSRectFill(rect);
	
	
	NSColor *startingColor = [NSColor colorWithRed:_frameColor.redComponent green:_frameColor.greenComponent blue:_frameColor.blueComponent alpha:0.75];
	NSGradient *aGradient = [[NSGradient alloc] initWithStartingColor:startingColor endingColor:_frameColor];
	[aGradient drawInRect:rect angle:90];
}

- (BOOL)isFlipped
{
	return YES;
}



#pragma mark - Apperance

- (void)setTitle:(NSString *)title
{
	_title = title;
	
	if (titleTextField) {
		[titleTextField removeFromSuperview];
	}
	
	titleTextField = [self defaultLabelWithString:title point:NSMakePoint(10, 2) textAlignment:NSLeftTextAlignment];
	[titleTextField setIdentifier:@"title"];
	[titleTextField setAllowsEditingTextAttributes:YES];
	[titleTextField setFont:_titleFont];
	[titleTextField setTextColor:_titleColor];
	[titleTextField sizeToFit];
	
	[self addSubview:titleTextField];
	[self setNeedsDisplay:YES];
}

- (void)setColor:(NSColor *)color
{
	_frameColor = color;
	[self setNeedsDisplay:YES];
}



- (void)traceSuperClassesOfObject:(NSObject *)obj
{
	Class currentClass = [obj class];
	NSString *classStructure = NSStringFromClass(currentClass);
	
	
	while (NSStringFromClass([currentClass superclass]) != nil)
	{
		currentClass = [currentClass superclass];
		classStructure = [classStructure stringByAppendingString:[NSString stringWithFormat:@" : %@", NSStringFromClass(currentClass)]];
	}
	
	[self setTitle:classStructure];
}

#pragma mark - Save

- (void)saveDebugView
{
	NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
	NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"]; 	// example: 1.0.0
	NSString *buildNumber = [infoDict objectForKey:@"CFBundleVersion"]; 			// example: 42
	
	NSURL *url = [_saveUrl URLByAppendingPathComponent:appVersion];
	url = [url URLByAppendingPathComponent:buildNumber];
	
	NSError *error;
	if (![[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error])
	{
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert runModal];
		return;
	}
	
	NSDictionary *debuggedObjects = [[pkDebugSettings sharedSettings] debuggedObjects];
	NSInteger debuggedNr = [[debuggedObjects valueForKey:[_obj className]] integerValue];
	debuggedNr++;
	[debuggedObjects setValue:[NSNumber numberWithInteger:debuggedNr] forKey:[_obj className]];
	url = [url URLByAppendingPathComponent:[NSString stringWithFormat:@"%@ %li", [_obj className], debuggedNr]];
	
	if (_saveAsPDF) {
		url = [url URLByAppendingPathExtension:@"pdf"];
	} else {
		url = [url URLByAppendingPathExtension:@"png"];
	}
	
	
	[self saveDebugViewToUrl:url];
}

- (BOOL)saveDebugViewToUrl:(NSURL *)url
{
	if ([[url pathExtension] isEqualToString:@"pdf"])
	{
		NSData *data = [self dataWithPDFInsideRect:[self bounds]];
		return [data writeToURL:url atomically:YES];
	}
	
	
	NSBitmapImageRep *rep = [self bitmapImageRepForCachingDisplayInRect:self.bounds];
	[self cacheDisplayInRect:self.bounds toBitmapImageRep:rep];
	
	NSData *data = [rep representationUsingType:NSPNGFileType properties:nil];
	return [data writeToURL:url atomically:YES];
}



#pragma mark - Add Data

- (void)addAllPropertiesFromObject:(NSObject *)obj includeSubclasses:(BOOL)include
{
	[self traceSuperClassesOfObject:obj];
	
	if (include)
	{
		// enumerate all subclasses "class_copyPropertyList(...)"
		Class currentClass = [obj class];
		
		while (currentClass != nil)
		{
			[propertyEnumerator enumerateProperties:currentClass allowed:nil block:^(NSString *type, NSString *name) {
				[self addProperty:name type:type toObject:obj];
			}];
			
			[self addSeperator];
			
			currentClass = [currentClass superclass];
		}
	}
	else
	{
		[propertyEnumerator enumerateProperties:[obj class] allowed:nil block:^(NSString *type, NSString *name) {
			[self addProperty:name type:type toObject:obj];
		}];
	}
}

- (void)addProperties:(NSString *)string fromObject:(NSObject *)obj
{
	if (string && string.length > 0)
	{
		NSArray *properties = [string componentsSeparatedByString:@", "];
		
		if (!properties)
		{
			@throw @"malformed properties parameter!";
		}
		
		[properties enumerateObjectsUsingBlock:^(id key, NSUInteger idx, BOOL *stop) {
			
			// TODO: enumerate subclasses
			[self addProperty:key type:[propertyEnumerator propertyTypeFromName:key object:obj] toObject:obj];
		}];
	}
}



- (void)addLineWithDescription:(NSString *)desc string:(NSString *)value
{
	if (value == nil || value == NULL || [value isEqualToString:@"(null)"])
	{
		value = @"nil";
		
		if (_highlightKeywords == true) {
			[self _addLineWithDescription:desc string:value leftColor:_propertyNameColor rightColor:_keywordColor leftFont:_propertyNameFont rightFont:_keywordFont];
		} else {
			[self _addLineWithDescription:desc string:value leftColor:_propertyNameColor rightColor:_textColor leftFont:_propertyNameFont rightFont:_keywordFont];
		}
	}
	else
	{
		[self _addLineWithDescription:desc string:value leftColor:_propertyNameColor rightColor:_textColor leftFont:_propertyNameFont rightFont:_textFont];
	}
}

- (void)addLineWithDescription:(NSString *)desc integer:(NSInteger)integer
{
	NSString *number = [NSString stringWithFormat:@"%li", integer];
	
	if (_highlightNumbers) {
		[self _addLineWithDescription:desc string:number leftColor:_propertyNameColor rightColor:_numberColor leftFont:_propertyNameFont rightFont:_numberFont];
	} else {
		[self _addLineWithDescription:desc string:number leftColor:_propertyNameColor rightColor:_textColor leftFont:_propertyNameFont rightFont:_textFont];
	}
}

- (void)addLineWithDescription:(NSString *)desc unsignedInteger:(NSUInteger)uinteger
{
	NSString *number = [NSString stringWithFormat:@"%lu", uinteger];
	
	if (_highlightNumbers) {
		[self _addLineWithDescription:desc string:number leftColor:_propertyNameColor rightColor:_numberColor leftFont:_propertyNameFont rightFont:_numberFont];
	} else {
		[self _addLineWithDescription:desc string:number leftColor:_propertyNameColor rightColor:_textColor leftFont:_propertyNameFont rightFont:_keywordFont];
	}
}

- (void)addLineWithDescription:(NSString *)desc longnumber:(long long)number
{
	NSString *num = [NSString stringWithFormat:@"%lli", number];
	
	if (_highlightNumbers) {
		[self _addLineWithDescription:desc string:num leftColor:_propertyNameColor rightColor:_numberColor leftFont:_propertyNameFont rightFont:_numberFont];
	} else {
		[self _addLineWithDescription:desc string:num leftColor:_propertyNameColor rightColor:_textColor leftFont:_propertyNameFont rightFont:_keywordFont];
	}
}

- (void)addLineWithDescription:(NSString *)desc unsignedLongnumber:(unsigned long long)number
{
	NSString *num = [NSString stringWithFormat:@"%llu", number];
	
	if (_highlightNumbers) {
		[self _addLineWithDescription:desc string:num leftColor:_propertyNameColor rightColor:_numberColor leftFont:_propertyNameFont rightFont:_numberFont];
	} else {
		[self _addLineWithDescription:desc string:num leftColor:_propertyNameColor rightColor:_textColor leftFont:_propertyNameFont rightFont:_keywordFont];
	}
}

- (void)addLineWithDescription:(NSString *)desc floating:(double)floating
{
	NSString *number = [NSString stringWithFormat:@"%3.8f", floating];
	
	if (_highlightNumbers) {
		[self _addLineWithDescription:desc string:number leftColor:_propertyNameColor rightColor:_numberColor leftFont:_propertyNameFont rightFont:_numberFont];
	} else {
		[self _addLineWithDescription:desc string:number leftColor:_propertyNameColor rightColor:_textColor leftFont:_propertyNameFont rightFont:_keywordFont];
	}
}

- (void)addLineWithDescription:(NSString *)desc boolean:(BOOL)boolean
{
	NSString *result;
	
	if (boolean) {
		result = @"YES";
	} else {
		result = @"NO";
	}
	
	if (_highlightKeywords) {
		[self _addLineWithDescription:desc string:result leftColor:_propertyNameColor rightColor:_keywordColor leftFont:_propertyNameFont rightFont:_keywordFont];
	} else {
		[self _addLineWithDescription:desc string:result leftColor:_propertyNameColor rightColor:_textColor leftFont:_propertyNameFont rightFont:_keywordFont];
	}
}

- (void)addLineWithDescription:(NSString *)desc image:(NSImage *)image
{
	NSTextField *left = [self defaultLabelWithString:desc point:NSMakePoint(10, pos) textAlignment:NSRightTextAlignment];
//	[left setStringValue:[left.stringValue capitalizedString]];		// all other letters will be lowercase
	[left setStringValue:[left.stringValue stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[left.stringValue substringToIndex:1] capitalizedString]]];
	
	
	[left setIdentifier:@"left"];
	[left setTextColor:_propertyNameColor];
	[left setFont:_propertyNameFont];
	[left sizeToFit];
	
	[left setFrame:NSMakeRect(left.frame.origin.x, left.frame.origin.y, left.frame.size.width, left.frame.size.height)];
	
	if (left.frame.size.width > leftWidth) {
		leftWidth = left.frame.size.width;
	}
	[self addSubview:left];
	
	
	
	NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(10 + leftWidth + 20, pos, _imageSize.width, _imageSize.height)];
	[imageView setImage:image];
	[imageView setIdentifier:@"rightImage"];
	[imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
	
	if (imageView.frame.size.width > rightWidth) {
		rightWidth = imageView.frame.size.width;
	}


	[self syncroniseHeightOfView:left secondView:imageView];
	pos = pos + imageView.frame.size.height + _lineSpace;
	[self addSubview:imageView];
	[self resizeLeftTextViews];
	[self resizeRightTextViews];
	[self setFrame:NSMakeRect(0, 0, 10 + leftWidth + 20 + rightWidth + 10, pos)];
}

- (void)addLineWithDescription:(NSString *)desc date:(NSDate *)date
{
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:_dateFormat];
	NSString *dateString = [dateFormatter stringFromDate:date];
	[self addLineWithDescription:desc string:dateString];
}

- (void)addSeperator
{
	// draw dashed line here
}

#pragma mark - Intern

- (void)addProperty:(NSString *)propertyName type:(NSString *)propertyType toObject:(NSObject *)obj
{
	id object = [[NSClassFromString(propertyType) alloc] init];		// every Obj-C Object ...
	if (object)
	{
		// not working for CoreData because lazy loading
		// should access data with getter (self.property)
		id property = [obj valueForKey:propertyName];

		
		if ([object isKindOfClass:[NSData class]])
		{
			if (_convertDataToImage && _propertyNameContains.count > 0)
			{
				BOOL contains = false;
				
				for (NSString *name in _propertyNameContains)
				{
					if ([propertyName rangeOfString:name options:NSCaseInsensitiveSearch].location != NSNotFound)
					{
						contains = true;
						break;
					}
				}
				
				
				
				if (contains)
				{
					// image Variable encoded as data
					NSData *data = (NSData *)property;
					
					NSImage *image = [[NSImage alloc] initWithData:data];
					
					if (image) {
						[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] image:image];
					} else {
						NSData *data = (NSData *)property;
						NSString *string = [NSString stringWithFormat:@"%@ ...", [pkDebugView getSubData:data withRange:NSMakeRange(0, 20)]];
						[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] string:string];
					}
				}
			}
			else
			{
				NSData *data = (NSData *)property;
				NSString *string = [NSString stringWithFormat:@"%@ ...", [pkDebugView getSubData:data withRange:NSMakeRange(0, 20)]];
				[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] string:string];
			}
		}
		else if ([object isKindOfClass:[NSDate class]])
		{
			[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] date:property];
		}
		else if ([object isKindOfClass:[NSImage class]])
		{
			if (property)
			{
				[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] image:property];
			}
		}
		else
		{
			NSString *string = [NSString stringWithFormat:@"%@", property];
			[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] string:string];
		}
		
	}
	else if ([propertyType isEqualToString:@"id"])										// id
	{
		id property = [obj valueForKey:propertyName];
		
		NSString *string = [NSString stringWithFormat:@"%@", property];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] string:string];
	}
	else if ([propertyType isEqualToString:@"NSURL"])									// NSURL
	{
		id property = [obj valueForKey:propertyName];
		
		NSString *string = [NSString stringWithFormat:@"%@", property];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] string:string];
	}
	else if ([propertyType isEqualToString:@"char"])										// Char & bool
	{
		// char
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] string:[NSString stringWithFormat:@"%c", [[obj valueForKey:propertyName] charValue]]];
		
		
//		NSNumber *number = [obj valueForKey:propertyName];
//		if ([number boolValue] == true)
//		{
//			[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] boolean:YES];
//		}
//		else
//		{
//			[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] boolean:NO];
//		}
	}
	else if ([propertyType isEqualToString:@"int"])										// Int
	{
		NSNumber *number = [obj valueForKey:propertyName];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] integer:[number integerValue]];
	}
	else if ([propertyType isEqualToString:@"short"])										// Short
	{
		NSNumber *number = [obj valueForKey:propertyName];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] integer:[number shortValue]];
	}
	else if ([propertyType isEqualToString:@"long"])										// long
	{
		NSNumber *number = [obj valueForKey:propertyName];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] integer:[number longValue]];
	}
	else if ([propertyType isEqualToString:@"long long"])										// long long
	{
		NSNumber *number = [obj valueForKey:propertyName];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] longnumber:[number longLongValue]];
	}
	else if ([propertyType isEqualToString:@"unsigned char"])										// unsigned char
	{
		NSNumber *number = [obj valueForKey:propertyName];
		char mchar = [number charValue];
		NSString *string = [NSString stringWithFormat:@"%c", mchar];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] string:string];
	}
	else if ([propertyType isEqualToString:@"unsigned int"])										// unsigned Int
	{
		NSNumber *number = [obj valueForKey:propertyName];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] unsignedInteger:[number unsignedIntegerValue]];
	}
	else if ([propertyType isEqualToString:@"unsigned short"])										// unsigned Short
	{
		NSNumber *number = [obj valueForKey:propertyName];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] integer:[number unsignedShortValue]];
	}
	else if ([propertyType isEqualToString:@"unsigned long"])										// unsigned long
	{
		NSNumber *number = [obj valueForKey:propertyName];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] unsignedInteger:[number unsignedLongValue]];
	}
	else if ([propertyType isEqualToString:@"unsigned long long"])										// unsigned long long
	{
		NSNumber *number = [obj valueForKey:propertyName];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] unsignedLongnumber:[number unsignedLongLongValue]];
	}
	else if ([propertyType isEqualToString:@"float"])										// float
	{
		NSNumber *number = [obj valueForKey:propertyName];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] floating:[number floatValue]];
	}
	else if ([propertyType isEqualToString:@"double"])										// double
	{
		NSNumber *number = [obj valueForKey:propertyName];
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] floating:[number doubleValue]];
	}
	else if ([propertyName isEqualToString:@"bool"])
	{
		NSNumber *number = [obj valueForKey:propertyName];
		if ([number boolValue] == true)
		{
			[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] boolean:YES];
		}
		else
		{
			[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] boolean:NO];
		}

	}
	else if ([propertyType isEqualToString:@"void"])										// char * (pointer)
	{
		NSString *string = [NSString stringWithFormat:@"%@", [obj valueForKey:propertyName]];
		
		[self addLineWithDescription:[NSString stringWithFormat:@"%@:", propertyName] string:[NSString stringWithFormat:@"%@", string]];
	}
	else
	{
		// if first char == '<' and last char == '>' then some delegate ...
		NSString *firstChar = [propertyType substringToIndex:1];
		NSString *lastChar = [propertyType substringFromIndex:propertyType.length-1];
		
		if ([firstChar isEqualToString:@"<"] && [lastChar isEqualToString:@">"])
		{
			// Delegate ...
			[self addLineWithDescription:propertyName string:propertyType];
		}
	}
}

- (void)syncroniseHeightOfView:(NSView *)left secondView:(NSView *)right
{
	CGFloat height = fmaxf(left.frame.size.height, right.frame.size.height);
	[left setFrame:NSMakeRect(left.frame.origin.x, left.frame.origin.y, left.frame.size.width, height)];
	[right setFrame:NSMakeRect(right.frame.origin.x, right.frame.origin.y, right.frame.size.width, height)];
}



- (void)_addLineWithDescription:(NSString *)desc string:(NSString *)value leftColor:(NSColor *)leftColor rightColor:(NSColor *)rightColor leftFont:(NSFont *)lFont rightFont:(NSFont *)rfont
{
	NSTextField *left = [self defaultLabelWithString:desc point:NSMakePoint(10, pos) textAlignment:NSRightTextAlignment];
	
	[left setStringValue:[left.stringValue stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[left.stringValue substringToIndex:1] capitalizedString]]];
	
	
	[left setIdentifier:@"left"];
	[left setTextColor:leftColor];
	[left setFont:lFont];
	[left sizeToFit];
	
//	[left setFrame:NSMakeRect(left.frame.origin.x, left.frame.origin.y, left.frame.size.width, left.frame.size.height)];
	
	if (left.frame.size.width > leftWidth) {
		leftWidth = left.frame.size.width;
	}
	[self addSubview:left];
	
	
	
	NSTextField *right = [self defaultLabelWithString:value point:NSMakePoint(10 + leftWidth + 20, pos) textAlignment:NSLeftTextAlignment];
	[right setIdentifier:@"right"];
	[right setTextColor:rightColor];
	[right setFont:rfont];
	[right sizeToFit];
	
	if (right.frame.size.width > rightWidth) {
		rightWidth = right.frame.size.width;
	}
	
	
	[self syncroniseHeightOfView:left secondView:right];
	pos = pos + fmaxf(left.frame.size.height, right.frame.size.height) + _lineSpace;
	[self addSubview:right];
	[self resizeLeftTextViews];
	[self resizeRightTextViews];
	[self setFrame:NSMakeRect(0, 0, 10 + leftWidth + 20 + rightWidth + 10, pos)];
}

- (NSTextField *)defaultLabelWithString:(NSString *)string point:(NSPoint)point textAlignment:(NSTextAlignment)align
{
	NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(point.x, point.y, 100, 100)];
	[textField setBordered:NO];
	[textField setEditable:NO];
	[textField setSelectable:YES];
	[textField setAlignment:align];
	[textField setBackgroundColor:[NSColor clearColor]];
	[textField setStringValue:string];

	return textField;
}

- (void)resizeLeftTextViews
{
	for (NSView *view in self.subviews)
	{
		if ([[view identifier] isEqualToString:@"left"])
		{
			[view setFrame:NSMakeRect(10, view.frame.origin.y, leftWidth + 10, view.frame.size.height)];
		}
	}
}

- (void)resizeRightTextViews
{
	for (NSView *view in self.subviews)
	{
		if ([[view identifier] isEqualToString:@"right"])
		{
			[view setFrame:NSMakeRect(10 + leftWidth + 20, view.frame.origin.y, rightWidth, view.frame.size.height)];
		}
		
		if ([[view identifier] isEqualToString:@"rightImage"])
		{
			[view setFrame:NSMakeRect(10 + leftWidth + 20, view.frame.origin.y, view.frame.size.width, view.frame.size.height)];
		}
	}
}

@end