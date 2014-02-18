JBCJSONKit
==========
Hello and welcome!

JBCJSONKit provides an implementation of NSJSONSerialization using a compressed JSON format described here: http://stevehanov.ca/blog/index.php?id=104

The idea is to extract repetitive property names from objects, reducing the size of JSON data. This should also allow uniquing of property names in the parsed objects as well.

Usage
-----
Simply replace uses of NSJSONSerialization with JBCJSONSerialization, like so:

JSON = [JBCJSONSerialization JSONObjectWithData:data
                                       options:0
                                        error:&error];

This will parse CJSON (or plain JSON) and return the encoded object.

data = [JBCJSONSerialization dataWithJSONObject:JSON
                                        options:0
                                          error:&error];

This will encode the given object using CJSON format, if possible.

Caveats
-------
The encoded CJSON will not be the same as the JS version above, as it uses NSJSONSerialization underneath, as NSDictionary keys are not ordered.

For example, the templates for the simple example given may end up being:

"t": [ [0, "x", "y" ], [ 0, "y", "x", "width", "height"] ]

instead of:

"t": [ [0, "x", "y"], [1, "width", "height"] ]

It should still be valid CJSON.
