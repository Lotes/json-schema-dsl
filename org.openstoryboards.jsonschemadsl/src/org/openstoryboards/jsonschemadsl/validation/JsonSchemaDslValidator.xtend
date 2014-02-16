package org.openstoryboards.jsonschemadsl.validation

import java.util.HashMap
import java.util.LinkedList
import java.util.List
import java.util.regex.Pattern
import org.eclipse.xtext.validation.Check
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Constraint
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Definition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.EnumDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.EnumLiteral
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.JsonSchemaDslPackage
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.RegexConstraint
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.TranslationUnit
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.DictionaryType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.ListType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StringType

class JsonSchemaDslValidator extends AbstractJsonSchemaDslValidator {
	def error(TypeData typeData, String message) {
		error(message, typeData.object, typeData.feature)
	}
	
	@Check
	def checkDefinitions(TranslationUnit unit) {
		//collect all definitions
		val map = new HashMap<String, List<Definition>>()
		for(Definition definition: unit.definitions) {
			val name = definition.name
			if(!map.containsKey(name))
				map.put(name, new LinkedList<Definition>())
			map.get(name).add(definition)				
		} 
		
		val net = new TypeNet()
		net.onError(TypeNet.ERROR_DICTIONARY_KEY_NOT_STRING, new TypeErrorCallback(this, "Dictionary's key type must be a string type."))
		net.onError(TypeNet.ERROR_DICTIONARY_KEY_NULLABLE, new TypeErrorCallback(this, "Dictionary's key type can not be null."))
		net.onError(TypeNet.ERROR_REFERENCED_TYPE_INTERACE, new TypeErrorCallback(this, "Cannot reference an interface in a type definition."))
		net.onError(TypeNet.ERROR_TYPE_UNKNOWN, new TypeErrorCallback(this, "Unknown type."))
		net.onError(TypeNet.ERROR_TYPE_CYCLIC_DEPENDENCY, new TypeErrorCallback(this, "Cyclic dependency found."))
		net.onError(TypeNet.ERROR_STRUCT_SUPER_TYPE_NOT_STRUCT, new TypeErrorCallback(this, "Super type must be a struct type."))
		net.onError(TypeNet.ERROR_STRUCT_SUPER_TYPE_NULL, new TypeErrorCallback(this, "Super type can not be null."))
		net.onError(TypeNet.ERROR_STRUCT_MEMBER_NOT_UNIQUE, new TypeErrorCallback(this, "Struct member is not unique."))
		net.onError(TypeNet.ERROR_STRUCT_MEMBER_OVERRIDDEN, new TypeErrorCallback(this, "Struct member overrides super member."))
		net.onError(TypeNet.ERROR_INTERFACE_MEMBER_NOT_UNIQUE, new TypeErrorCallback(this, "Interface member name have to be unique."));
		net.onError(TypeNet.ERROR_PARAMETER_NOT_UNIQUE, new TypeErrorCallback(this, "Parameter names have to be unique."));

		//filter unique definitions, throw errors on duplicates
		for(String name: map.keySet) {
			val definitions = map.get(name)
			if(definitions.size > 1) {
				for(Definition definition: definitions) {
					error("Type names have to be unique", definition, JsonSchemaDslPackage.Literals::DEFINITION__NAME);	
				}
			} else {
				net.addDefinition(definitions.get(0))
			}
		}
		
		net.resolveTypes()
	}
	
	@Check
	public def checkRegex(RegexConstraint constraint) {
		val pattern = constraint.pattern
		try {
			Pattern.compile(pattern.substring(1, pattern.length-1))
		} catch(Exception ex) {
			error("Invalid regular expression ("+ex.message+").", constraint, JsonSchemaDslPackage.Literals::REGEX_CONSTRAINT__PATTERN)
		}
	}
	
	@Check
	public def checkConstraint(Constraint constraint) {
		val openLeft = constraint.left.bracket.equals("(")
		val openRight = constraint.left.bracket.equals(")")
		val container = constraint.eContainer
		val isSizeConstraint = container instanceof DictionaryType 
			|| container instanceof ListType
			|| container instanceof StringType;
			
		if(constraint.from != null) {
			val from = constraint.from.value
			if(isSizeConstraint && from < 0)
				error("Lower limit of size constraint cannot be negative.", constraint, JsonSchemaDslPackage.Literals::CONSTRAINT__FROM)					
			if(constraint.to != null) {
				val to = constraint.to.value
				if(isSizeConstraint && to < 0)
					error("Upper limit of size constraint cannot be negative.", constraint, JsonSchemaDslPackage.Literals::CONSTRAINT__TO)
				if(from > to)
					error("Upper limit must be bigger or equal than lower limit.", constraint, JsonSchemaDslPackage.Literals::CONSTRAINT__FROM)
				else if(from == to && (openLeft || openRight))
					error("Constraint results in empty type.", constraint, JsonSchemaDslPackage.Literals::CONSTRAINT__FROM)
			} else {
				if(openLeft || openRight)
					error("Constraint results in empty type.", constraint, JsonSchemaDslPackage.Literals::CONSTRAINT__FROM)
			}	
		} else {
			if(constraint.to != null) {
				if(isSizeConstraint && constraint.to.value < 0)
					error("Upper limit of size constraint cannot be negative.", constraint, JsonSchemaDslPackage.Literals::CONSTRAINT__TO)			
			} else {
				error("Empty constraint detected.", constraint, JsonSchemaDslPackage.Literals::CONSTRAINT__LEFT)
			}
		}
	}
	
	@Check
	def checkUniqueEnumLiteral(EnumDefinition definition) {
		val map = new HashMap<String, List<EnumLiteral>>()
		for(EnumLiteral literal: definition.literals) {
			val name = literal.name
			if(!map.containsKey(name))
				map.put(name, new LinkedList<EnumLiteral>())
			map.get(name).add(literal);
		}
		for(String name: map.keySet) {
			val list = map.get(name)
			if(list.size > 1) {
				for(EnumLiteral literal: list){
					error("Enumeration literals have to be unique", literal, JsonSchemaDslPackage.Literals::ENUM_LITERAL__NAME);	
				}	
			}
		}	
	}
}
