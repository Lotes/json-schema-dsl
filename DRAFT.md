This document describes a DSL (domain specific language) for defining a JSON data schema. A schema contains definitions of constants, annotations and types.

Constants can be used for definition of annotations and types.

Annotations can be used for describing metadata at type and type property definitions.

The idea is to formulate a DSL and then derive a meta-schema in JSON.

#TODO

* tuples: `typedef Point3D = tuple of (integer, integer, integer);`

* erase enumerations: `typedef Enum = string /^(VALUE1|VALUE2|VALUE3)$/;`

* extends strings:

```
typedef Identifier = string /^[a-zA-Z_][a-zA-Z_0-9]*$/; 
typedef ShortIdentifier = Identifier[..5];             
typedef CapitalIdentifier = Identifier /^[A-Z_0-9]+$/;

#also possible with the "and" operator
typedef ShortIdentifier = Identifier and string[..5];             
typedef CapitalIdentifier = Identifier and string /^[A-Z_0-9]+$/;
```

Built-in types:
```
- any
- null
- boolean
- integer
- string
- number 
- typedef Size = integer[0..];
- typedef Identifier = string /^[a-zA-Z_][a-zA-Z_0-9]*$/; 
```

#Assumptions

For simplicity "null" is equal to "undefined".

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

## Inline types vs. named types

Types can be used inline or defined with a name. Examples:
```
struct Object {               #named object type 
	property: null or string; #inline union of the two types "null" and "string"
};

#this type can also be written as "typedef"
typedef Object = struct {
	property: ...;
};
```

## Special types

### "null" type

The "null" type describes the `null` value.

### "any" type

The "any" type describes any JSON data (including `null`).
To exclude types use the `except` keyword:
```
typedef AnyButNotNull = any except null;
```

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

Shall I define constraints on booleans? It doesn't make sense to me.

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
typedef CountryCode = string[..3] /^[A-Z]+$/; #up to 3 characters
```

Or you can define enumerations. The name of the enumeration literal is also the value of the string:
```
enum Orientation {
	HORIZONTAL, #value is "HORIZONTAL"
	VERTICAL    #value is "VERTICAL"
};

#can be also written as
typedef Orientation = enum {
	HORIZONTAL,
	VERTICAL
};

#the values can be accessed like this:
value = Orientation.HORIZONTAL
```

Enumerations can inherit from other enumerations:
```
enum E0 { X, Y, Z };
enum E1 { A, B, C };                   #base
enum E2: E1 { D, E, F };               #single inheritance
typedef E3 = enum: E0, E2 { G, H, I }; #multiple inheritance, inline definition
```

### Integers

This type defines integers like `0`, `123`, `-456`...

It can be contrained with upper and lower bounds or with an enumeration of values.

```
typedef JustIntegers = integer;            #all integers
typedef NonPositiveInteger = integer[..0]; #.. -3, -2, -1, 0
typedef NonNegativeInteger = integer[0..]; #0, 1, 2, 3, ..
typedef PositiveInteger = integer(0..];    #1, 2, 3, .. Mind the round parethesis!
typedef NegativeInteger = integer[..0);    #.. -3, -2, -1
typedef EnumerationInts = integer[1,2,4];  #only the values 1, 2, 4
```

### Numbers

This numeric type also includes floating point numbers. It has the same constraints syntax like the "integer" type.

```
typedef JustNumbers = number;                 #all numbers
typedef PositiveFloat = number(0..];          #0.2, 3.14, 88.0 .. Mind the round parethesis!
typedef NegativeFloat = number[..0);          #-0.1, -2.25, -123.0 ..
typedef NonPositiveFloat = number[..0];       #0, -0.1, -2.25, -123.0 ..
typedef NonNegativeFloat = number[0..];       #0, 0.2, 3.75, 5864.33 ..
typedef EnumerationFloat = number[1.4, -3.7]; #only the values 1.4 and -3.7
```

TODO: choose another name than "number" like "float", "real", "double".

## Lists

A list is a container type - it contains elements of a given type. A list of `Type` elements can be written as
```
typedef CustomList = list of Type;
``` 

Besides that you can constrain lists in its size:
```
const BLOCK_SIZE: integer = 5;
typedef FixedIntBlock = list[BLOCK_SIZE] of integer;   #exactly 5 entries 
typedef VarIntBlock = list[2..BLOCK_SIZE] of integer;  #2 to 5 entries
typedef MinIntBlock = list(BLOCK_SIZE..] of integer;   #6 and more entries, mind the round parenthesis!
typedef UnboundedIntBlock = list of integer;           #list of any size
typedef EvenSizedIntBlock = list[2,4,6,8] of integer;  #list of 2, 4, 6 or 8 entries
```

Values of `FixedIntBlock` could be `[1, 2, 3, 4, 5]` or [-1, 34, 71, -911, 0].

## Dictionaries

A dictionary is also a container type - but of key-value-pairs. It needs a string type for the keys and any other type for the values:

```
typedef Key = string /^[A-Z]$/; #any capital letter
typedef Value = integer(100..200); #any integer between 100 and 200
typedef CustomDictionary = dictionary of Key => Value;
```

You can also constrain a dictionary in its size:
```
typedef UnboundedIntConstants = dictionary of Identifier => integer;        #dictionary of any size
typedef VarIntConstants = dictionary[2..10] of Identifier => integer;       #2 to 10 entries
typedef FixedIntConstants = dictionary[5] of Identifier => integer;         #exactly 5 entries
typedef MaxIntConstants = dictionary[..5] of Identifier => integer;         #at most 5 entries
typedef OddSizedConstants = dictionary[1,3,5,7,9] of Identifier => integer; #dictionary of 1, 3, 5, 7, 9 entries
```

Values of `MaxIntConstants` could be `{}` or `{abc: 123, def: 456}`.

## Structs

Struct types are mapped to JSON objects. Each object property can be defined with its name and its type. 

```
struct Person {
	name: string;
	age: integer;
};

#can also be written as
typedef Person = struct { ... };

###
allows values like 
{ name: "Tom", age: 18 }, 
{ name: "Susan", age: 27 }
but also additional properties like 
{ name: "Tiffany", age: 33, title: "PhD" }
are accepted.
###
```

There are lenient and strict structs. By default structs are lenient. A lenient struct allows additional properties beyond the defined ones (like in the above example). Strict struct forbid additional properties:

```
strict struct StrictPerson {
	name: string;
	age: integer;
};
###
allows  { name: "Susan", age: 27 }
forbids { name: "Tiffany", age: 33, title: "PhD" }
###
```

### inheritance

Structs can inherit properties from other structs (more than one!).

Example:
```
struct Person {
	name: string;
	age: integer;
};

struct Employee: Person {
	personnelNumber: integer;
	department: string;
};

struct Student: Person {
	matriculationNumber: integer;
	studyCourse: string;
};

struct Tutor: Employee, Student {
	tutorModule: string;
};

#can also be written as
typedef Tutor = struct: Employee, Student { ... };

###
valid value for "Tutor":
{
  name: "Tom", 
  age: 18, 
  personnelNumber: 123456, 
  department: "IT", 
  matriculationNumber: 4140073,
  studyCourse: "Computer Science",
  tutorModule: "TI II"
}
###
```

Important: There is no polymorphism! A list of `Person` (can but) should not contain a list of `Employee`!












### `switch` and `list_switch`

Struct properties can depend on each other. To express these dependencies you can use the `switch` and the `list_switch` keyword.

enum MessageType {
	AAA,
	BBB
}

struct Message {
	type: MessageType
	switch type {
		case AAA:
			message: integer
		case BBB:
			message: boolean
	}
}

struct SwitchExample {
	id: integer
	switch(id) {
		case [1..10):                       #range, actual range 0..9
		case 11:                            #single value
		case [-20,-10,12]:                  #list of values
		case [1..10] or 11 or [-20,-10,12]: #one of the top three cases
		case [1..5] and 3 and [3,2,1]:      #all of the top three cases
		case 1 or 2 and 3                   #1 or (2 and 3)
		default:                            #else case
	}
}

struct ArraySwitchExample {
	list: array of integer
	array_switch(list) {              #find a better keyword than "array_switch"
		case 1:                       #list contains 1
		case [2..4):                  #list contains 2 and 3
		case [7,-8,9]:                #list contains 7, -8, 9
		case 1 or [2..4) or [7,-8,9]: #list contains one of the top three cases
		case 1 and [1..4) and [1,2]:  #list contains all of the top three cases
		case 1 or 2 and 3             #list contains 1 or (2 and 3)
		default:                      #else case
	}
}










## Operations on types

### Union
You can build the union of types using the `or` operator:
```
typedef NullableString = null or string; #null, "abc", "", "123"
```

### And

To intersect two or more types use the `and` operator.
```
typedef Zero = NonPositiveInteger and NonNegativeInteger
```

### Except

You can forbid a subset of type using the `except` operator.
```
typedef AnyButNotNull = any except null
typedef AnyButNotPrimitive = any except (boolean or string or integer or number)
```

### Optional

Types can be optional using the `?` operator:
```
struct Node {
  content: integer;
  left: Node?;
  right: Node?;
};

#Type? === NullableType with typedef NullableType = null or Type;

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

### Operator precedence

Priority | Operator | Description | Associativity
--- | --- | --- | ---
1 | A? | type A is nullable | 
2 | not A | any but not type A | 
3 | A except B | type A without type B | left-to-right
4 | A and B | intersection of types A and B | left-to-right
5 | A or B | union of types A and B | left-to-right

## Constants 

Constants are values of a certain type that can be used for further definitions.

```
const NAME: Type = value;
const BLOCK_SIZE: integer = 5  ;
const LIST: UnboundedIntBlock = [1,2,3];
const PERSON: Person = {
	name: "Tom",
	age: 12
};
const SOMETHING: any = 123;
```

## Annotations

Annotations add meta information to the schema structure that will be generated by the schema parser. They can have any number of arguments. Each argument must have a type and can have a default value.

```
annotation Description(text: string);
annotation Format(kind: string, param: integer = 0);

@Description("Only integers <= 0")
@Format(FormatType.NUMBER_SPIN)
typedef NonPositiveInteger = integer[..0] #..-3, -2, -1, 0
```
