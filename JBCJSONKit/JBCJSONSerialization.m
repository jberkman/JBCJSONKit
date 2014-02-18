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

@interface JBCJSONSerialization ()
+ (id)JSONObjectWithCJSONObject:(id)obj;
+ (id)CJSONObjectWithJSONObject:(id)obj;
@end

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

+ (void)expandObject:(id)obj
              values:(NSEnumerator *)values
       templateIndex:(NSUInteger)templateIndex
           templates:(NSArray *)templates
{
    if (!templateIndex) {
        return;
    }
    [templates[templateIndex - 1] enumerateObjectsUsingBlock:^(id key, NSUInteger idx, BOOL *stop) {
        if (idx) {
            obj[key] = [self expandValue:values.nextObject
                               templates:templates];
        } else {
            [self expandObject:obj
                        values:values
                 templateIndex:[key unsignedIntegerValue]
                     templates:templates];
        }
    }];
}

+ (id)expandValue:(id)value
        templates:(NSArray *)templates
{
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[value count]];
        [value enumerateObjectsWithOptions:0
                                usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
         {
             ret[idx] = [self expandValue:obj
                                templates:templates];
         }];
        value = ret;
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *ret = [NSMutableDictionary new];
        NSEnumerator *values = [value[ObjectValueKey] objectEnumerator];
        [self expandObject:ret
                    values:values
             templateIndex:[values.nextObject unsignedIntegerValue]
                 templates:templates];
        value = ret;
    }
    return value;
}

+ (id)JSONObjectWithCJSONObject:(id)obj
{
    if (![obj isKindOfClass:[NSDictionary class]] ||
        ![CJSONFormat isEqual:obj[FormatKey]]) {
        return obj;
    }
    return [self expandValue:obj[ValueKey]
                   templates:obj[TemplateKey]];
}

+ (id)JSONObjectWithData:(NSData *)data
                 options:(NSJSONReadingOptions)opt
                   error:(NSError *__autoreleasing *)error
{
    return [self JSONObjectWithCJSONObject:[super JSONObjectWithData:data
                                                             options:opt
                                                               error:error]];
}

@end
