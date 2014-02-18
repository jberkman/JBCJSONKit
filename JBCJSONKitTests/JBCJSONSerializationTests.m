//
//  JBCJSONSerializationTests.m
//  JBCJSONKit
//
//  Created by jacob berkman on 2/17/14.
//  Copyright (c) 2014 87k Networks. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <JBCJSONKit/JBCJSONKit.h>

@interface JBCJSONSerializationTests : XCTestCase

@end

@implementation JBCJSONSerializationTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)testSimple
{
    static NSString * const JSONStr = @"[{\"x\":100,\"y\":100},{\"x\":100,\"y\":100,\"width\":200,\"height\":150}]";
    static NSString * const CJSONStr = @"{"
        "\"f\":\"cjson\","
        "\"t\":[[0,\"x\",\"y\"],[1,\"width\",\"height\"]],"
        "\"v\":[{\"\":[1,100,100]},{\"\":[2,100,100,200,150]}]}";

    NSError *error;
    id obj = [JBCJSONSerialization JSONObjectWithData:[CJSONStr dataUsingEncoding:NSUTF8StringEncoding]
                                              options:0
                                                error:&error];
    XCTAssertNotNil(obj, @"CJSON parsing failed.");
    XCTAssertNil(error, @"Error parsing CJSON: %@", error);
    XCTAssertTrue([obj isKindOfClass:[NSArray class]], @"%@ is not an array.", NSStringFromClass([obj class]));

    id obj2 = [NSJSONSerialization JSONObjectWithData:[JSONStr dataUsingEncoding:NSUTF8StringEncoding]
                                              options:0
                                                error:&error];
    XCTAssertNotNil(obj2, @"JSON parsing failed.");
    XCTAssertNil(error, @"Error parsing JSON object: %@", error);
    error = nil;

    XCTAssertEqualObjects(obj, obj2, @"CJSON object didn't parse correctly.");

    NSData *data = [JBCJSONSerialization dataWithJSONObject:obj
                                                    options:0
                                                      error:&error];
    XCTAssertNotNil(data, @"CJSON serialization failed.");
    XCTAssertNil(error, @"Error serializing CJSON object.");

    obj = [NSJSONSerialization JSONObjectWithData:data
                                          options:0
                                            error:&error];
    XCTAssertNotNil(obj, @"JSON parsing of serialized CJSON object failed.");
    XCTAssertNil(error, @"Error parsing serialized CJSON object: %@", error);
    XCTAssertTrue([obj isKindOfClass:[NSDictionary class]], @"Serialized CJSON object is a %@", NSStringFromClass([obj class]));
    error = nil;

    obj2 = [NSJSONSerialization JSONObjectWithData:[CJSONStr dataUsingEncoding:4]
                                           options:0
                                             error:&error];
    XCTAssertNotNil(obj2, @"JSON parsing failed.");
    XCTAssertNil(error, @"Error parsing JSON object: %@", error);
    error = nil;

    XCTAssertEqualObjects(obj, obj2, @"CJSON object didn't serialize correctly.");
}

- (void)testZwibbler
{
    static NSString * const FileName = @"zwibbler";
    static NSString * const JSONExtension = @"json";
    static NSString * const CJSONExtension = @"cjson";

    NSError *error;
    NSURL *URL;
    NSData *data;
    NSUInteger JSONLength;
    id JSON;
    id CJSON;

    URL = [[NSBundle bundleForClass:self.class] URLForResource:FileName
                                                 withExtension:JSONExtension];

    data = [NSData dataWithContentsOfURL:URL];
    XCTAssertNotNil(data, @"Could not load JSON");
    JSONLength = data.length;

    error = nil;
    JSON = [NSJSONSerialization JSONObjectWithData:data
                                           options:0
                                             error:&error];
    XCTAssertNotNil(JSON, @"Could not parse JSON");
    XCTAssertNil(error, @"Error parsing JSON: %@", error);

    URL = [[NSBundle bundleForClass:self.class] URLForResource:FileName
                                                 withExtension:CJSONExtension];
    data = [NSData dataWithContentsOfURL:URL];
    XCTAssertNotNil(data, @"Could not load CJSON");

    error = nil;
    CJSON = [JBCJSONSerialization JSONObjectWithData:data
                                             options:0
                                               error:&error];
    XCTAssertNotNil(JSON, @"Could not parse CJSON");
    XCTAssertNil(error, @"Error parsing CJSON: %@", error);

    XCTAssertEqualObjects(CJSON, JSON, @"CJSON object didn't parse correctly.");

    error = nil;
    data = [JBCJSONSerialization dataWithJSONObject:CJSON
                                            options:0
                                              error:&error];
    XCTAssertNotNil(JSON, @"Could not serialize CJSON");
    XCTAssertNil(error, @"Error serializing CJSON: %@", error);

    error = nil;
    JSON = [JBCJSONSerialization JSONObjectWithData:data
                                            options:0
                                              error:&error];
    XCTAssertNotNil(JSON, @"Could not parse CJSON");
    XCTAssertNil(error, @"Error parsing CJSON: %@", error);

    XCTAssertEqualObjects(CJSON, JSON, @"CJSON object didn't serialize correctly.");

    NSLog(@"Compressed from %ld to %ld bytes (%fX)", JSONLength, data.length,
          (double)data.length / JSONLength);
}

@end
