package org.openstoryboards.jsonschemadsl.validation

enum TypeKind {
	UNKNOWN,
	
	STRUCT,
	ENUM,
	INTERFACE,
	
	BOOLEAN,
	ANY,
	NULL,
	INTEGER,
	NUMBER,
	STRING,
	
	DICTIONARY,
	LIST,
	TUPLE
}