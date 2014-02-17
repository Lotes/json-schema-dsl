This document describes a DSL (domain specific language) for defining a JSON data schema. A schema contains definitions of types and interface (for remote procedure calls).

#Assumptions

For simplicity "null" is equal to "undefined".

TODO: overthink this

#Language components

## Comments

```
typedef A = string #this is a single line comment

###
This is a 
multi-line 
comment.
###
```

## Special types

### "null" type

The "null" type describes the `null` value.

### "any" type

The "any" type describes any JSON data (including `null`).

## Primitive types

### Booleans

Booleans describe the values `true` and `false`.

```
typedef RenamedBoolean = boolean;
struct Stats {
  isFile: boolean;
  isDirectory: RenamedBoolean;
};
```

TODO: Shall I define constraints on booleans? It doesn't make sense to me.

### Strings

The "string" type describe any character data inside of double quotes like `"abc"`, `"123"`, `"@>-',-',-"`.

You can constrain strings using a regular expression:
```
typedef JustStrings = string;
typedef Identifier = string /^[a-zA-Z_][a-zA-Z_0-9]*$/;
#"abc123", "_1Aa", "lutscher"
```

You can also constrain strings in their length:
```
typedef ZipCode = string[5] /^\d+$/;          #exactly 5 characters
typedef CountryCode = string[...3] /^[A-Z]+$/; #up to 3 characters
```

### Integers

This type defines integers like `0`, `123`, `-456`...

It can be contrained with upper and lower bounds or with an enumeration of values.

```
typedef JustIntegers = integer;            #all integers
typedef NonPositiveInteger = integer[...0]; #.. -3, -2, -1, 0
typedef NonNegativeInteger = integer[0...]; #0, 1, 2, 3, ..
typedef PositiveInteger = integer(0...];    #1, 2, 3, .. Mind the round parethesis!
typedef NegativeInteger = integer[...0);    #.. -3, -2, -1
```

### Numbers

This numeric type also includes floating point numbers. It has the same constraints syntax like the "integer" type. Upper and lower limit must be integers.

```
typedef JustNumbers = number;                 #all numbers
typedef PositiveFloat = number(0...];          #0.2, 3.14, 88.0 .. Mind the round parenthesis!
typedef NegativeFloat = number[...0);          #-0.1, -2.25, -123.0 ..
typedef NonPositiveFloat = number[...0];       #0, -0.1, -2.25, -123.0 ..
typedef NonNegativeFloat = number[0...];       #0, 0.2, 3.75, 5864.33 ..
```

TODO: choose another name than "number" like "float", "real", "double".

## Enumerations

Enumerations are named integers:
```
enum Orientation {
	HORIZONTAL, #synonym for 0
	VERTICAL    #synonym for 1
}
```

## Lists

A list is a container type - it contains elements of a given type. A list of `Type` elements can be written as
```
typedef CustomList = list of Type;
``` 

Besides that you can constrain lists in its size:
```
typedef FixedIntBlock = list[5] of integer;   #exactly 5 entries 
typedef VarIntBlock = list[2...5] of integer; #2 to 5 entries
typedef MinIntBlock = list(5...] of integer;  #6 and more entries, mind the round parenthesis!
typedef UnboundedIntBlock = list of integer;  #list of any size
```

Values of `FixedIntBlock` could be `[1, 2, 3, 4, 5]` or [-1, 34, 71, -911, 0].

## Tuples

A tuple is mapped to finite lists where each element has a certain type. Tuples have no constraints.

```
typedef Point = tuple of (integer, integer) 
#example value: [123, -456]
```

## Dictionaries

A dictionary is also a container type - but of key-value-pairs. It needs a string type for the keys and any other type for the values:

```
typedef Key = string /^[A-Z]$/; #any capital letter
typedef Value = integer(100...200); #any integer between 100 and 200
typedef CustomDictionary = dictionary of Key => Value;
```

You can also constrain a dictionary in its size:
```
typedef UnboundedIntConstants = dictionary of Identifier => integer;        #dictionary of any size
typedef VarIntConstants = dictionary[2...10] of Identifier => integer;       #2 to 10 entries
typedef FixedIntConstants = dictionary[5] of Identifier => integer;         #exactly 5 entries
typedef MaxIntConstants = dictionary[...5] of Identifier => integer;         #at most 5 entries
```

Values of `MaxIntConstants` could be `{}` or `{abc: 123, def: 456}`.

## Structs

Struct types are mapped to JSON objects. Each object property can be defined with its name and its type. 

```
struct Person {
	name: string;
	age: integer;
};

###
allows values like 
{ name: "Tom", age: 18 }, 
{ name: "Susan", age: 27 }
but also additional properties like 
{ name: "Tiffany", age: 33, title: "PhD" }
are accepted.
###
```

### Inheritance

Structs can inherit properties from another struct.

Example:
```
abstract struct Person {
	name: string;
	age: integer;
};

struct Employee: Person {
	personnelNumber: integer;
	department: string;
};

###
valid value for "Employee":
{
  name: "Tom", 
  age: 18, 
  personnelNumber: 123456, 
  department: "IT"
}
###
```

Attention: Don't forget the polymorphism! A list of `Person` can also contain a list of `Employee`!
Internally a field named `$type` will be inserted to identify the type.

Abstract struct should not be instantiated. If you try to validate against an abstract struct an exception will be thrown.

## Nullable types

Types can be nullable using the `nullable` keyword. Using this keyword you can define tree types (otherwise a cyclic dependency will be detected):

```
struct Node {
  content: integer;
  left: nullable Node;
  right: nullable Node;
};

###
possible Node value:
{
  content: 1,
  left: {
	content: 2,
	left: null,
	right: null
  },
  right: null
}
###
```