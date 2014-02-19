//
//  JBCJSONSerialization.m
//  JBCJSONKit
//
//  Created by jacob berkman on 2/17/14.
//  Copyright (c) 2014 87k Networks. All rights reserved.
//

#import "JBCJSONSerialization.h"

static NSString * const FormatKey = @"f";
static NSString * const ObjectValueKey = @"";
static NSString * const TemplateKey = @"t";
static NSString * const ValueKey = @"v";

static NSString * const CJSONFormat = @"cjson";

@interface JBCJSONNode : NSObject
@property (nonatomic, weak) JBCJSONNode *parent;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSMutableDictionary *children;
@property (nonatomic, assign) NSUInteger templateIndex;
@property (nonatomic, strong) NSMutableArray *links;
- (JBCJSONNode *)followKey:(NSString *)key;
@end

@implementation JBCJSONNode
- (NSMutableDictionary *)children
{
    if (_children) {
        return _children;
    }
    return _children = [NSMutableDictionary new];
}

- (NSMutableArray *)links
{
    if (_links) {
        return _links;
    }
    return _links = [NSMutableArray new];
}

- (JBCJSONNode *)followKey:(NSString *)key
{
    if (self.children[key]) {
        return self.children[key];
    }
    JBCJSONNode *node = [JBCJSONNode new];
    node.parent = self;
    node.key = key;
    return self.children[key] = node;
}
- (NSString *)description
{
    return [NSString stringWithFormat:@"\t%@[%ld] (%lu children)", self.key, self.templateIndex, self.children.count];
}
@end

@implementation JBCJSONSerialization

+ (id)templatizeObject:(id)obj
                  root:(JBCJSONNode *)root
{
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[obj count]];
        [obj enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            ret[idx] = [self templatizeObject:obj
                                         root:root];
        }];
        obj = ret;
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        JBCJSONNode * __block node = root;
        NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[obj count]];
        [obj enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            node = [node followKey:key];
            [ret addObject:[self templatizeObject:obj
                                             root:root]];
        }];
        obj = @{ObjectValueKey:ret};
        [node.links addObject:obj];
    }
    return obj;
}

+ (NSArray *)templatesWithRoot:(JBCJSONNode *)root
{
    NSMutableArray *todo = [root.children.allValues mutableCopy];
    NSMutableArray *templates = [NSMutableArray new];
    while (todo.count) {
        JBCJSONNode *node = todo.firstObject;
        [todo removeObjectAtIndex:0];

        [todo addObjectsFromArray:node.children.allValues];
        if (node.children.count < 2 && !node.links.count) {
            continue;
        }

        NSMutableArray *template = [NSMutableArray new];
        JBCJSONNode *cur;
        for (cur = node; !cur.templateIndex && cur.key; cur = cur.parent) {
            [template insertObject:cur.key
                           atIndex:0];
        }
        [template insertObject:@(cur.templateIndex)
                       atIndex:0];
        [templates addObject:template];
        node.templateIndex = templates.count;
        [node.links enumerateObjectsWithOptions:NSEnumerationConcurrent
                                     usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
         {
             [obj[ObjectValueKey] insertObject:@(node.templateIndex)
                                       atIndex:0];;
         }];
    }
    return templates;
}

+ (id)CJSONObjectWithJSONObject:(id)obj
{
    JBCJSONNode *root = [JBCJSONNode new];
    id values = [self templatizeObject:obj
                                  root:root];
    NSArray *templates = [self templatesWithRoot:root];
    if (!templates.count) {
        return obj;
    }
    return @{FormatKey:CJSONFormat,
             TemplateKey: templates,
             ValueKey: values};
}

+ (NSData *)dataWithJSONObject:(id)obj
                       options:(NSJSONWritingOptions)opt
                         error:(NSError *__autoreleasing *)error
{
    return [super dataWithJSONObject:[self CJSONObjectWithJSONObject:obj]
                             options:opt
                               error:error];
}

+ (NSInteger)writeJSONObject:(id)obj
                    toStream:(NSOutputStream *)stream
                     options:(NSJSONWritingOptions)opt
                       error:(NSError *__autoreleasing *)error
{
    return [super writeJSONObject:[self CJSONObjectWithJSONObject:obj]
                         toStream:stream
                          options:opt
                            error:error];
}

+ (id)expandValue:(id)value
        templates:(NSArray *)templates
          options:(NSJSONReadingOptions)opts
            error:(NSError * __autoreleasing *)error
{
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[value count]];
        [value enumerateObjectsWithOptions:0
                                usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
         {
             ret[idx] = [self expandValue:obj
                                templates:templates
                                  options:opts
                                    error:error];
         }];
        return (opts & NSJSONReadingMutableContainers) ? ret : [NSArray arrayWithArray:ret];
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        NSArray *values = value[ObjectValueKey];
        NSNumber *templateIndex = values.firstObject;
        values = [self expandValue:[values subarrayWithRange:NSMakeRange(1, values.count - 1)]
                         templates:templates
                           options:opts
                             error:error];
        id dict = (opts & NSJSONReadingMutableContainers) ? [NSMutableDictionary class] : [NSDictionary class];
        return [dict dictionaryWithObjects:values
                                   forKeys:templates[templateIndex.unsignedIntegerValue]];
    }
    return value;
}

+ (NSArray *)expandTemplates:(NSArray *)templates
{
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:templates.count + 1];
    ret[0] = @[];
    [templates enumerateObjectsUsingBlock:^(NSArray *template, NSUInteger idx, BOOL *stop) {
        NSNumber *templateIndex = template.firstObject;
        NSArray *newTemplate = ret[templateIndex.unsignedIntegerValue];
        NSArray *newKeys = [template subarrayWithRange:NSMakeRange(1, template.count - 1)];
        [ret addObject:[newTemplate arrayByAddingObjectsFromArray:newKeys]];
    }];
    // Immutify.
    return [NSArray arrayWithArray:ret];
}

+ (id)JSONObjectWithCJSONObject:(id)obj
                        options:(NSJSONReadingOptions)opt
                          error:(NSError * __autoreleasing *)error
{
    if (![obj isKindOfClass:[NSDictionary class]] ||
        ![CJSONFormat isEqual:obj[FormatKey]]) {
        return obj;
    }
    return [self expandValue:obj[ValueKey]
                   templates:[self expandTemplates:obj[TemplateKey]]
                     options:opt
                       error:error];
}

+ (id)JSONObjectWithData:(NSData *)data
                 options:(NSJSONReadingOptions)opt
                   error:(NSError *__autoreleasing *)error
{
    return [self JSONObjectWithCJSONObject:[super JSONObjectWithData:data
                                                             options:opt
                                                               error:error]
                                   options:opt
                                     error:error];
}

+ (id)JSONObjectWithStream:(NSInputStream *)stream
                   options:(NSJSONReadingOptions)opt
                     error:(NSError *__autoreleasing *)error
{
    return [self JSONObjectWithCJSONObject:[super JSONObjectWithStream:stream
                                                               options:opt
                                                                 error:error]
                                   options:opt
                                     error:error];
}

@end
