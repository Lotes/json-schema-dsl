package org.openstoryboards.jsonschemadsl.validation

import java.util.HashMap
import java.util.HashSet
import java.util.LinkedList
import java.util.List
import java.util.Map
import org.eclipse.emf.common.util.EList
import org.eclipse.xtext.validation.Check
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Definition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.EnumDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.EnumLiteral
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.JsonSchemaDslPackage
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StructDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StructMember
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.TranslationUnit
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.EnumType

class JsonSchemaDslValidator extends AbstractJsonSchemaDslValidator {
	@Check
	def checkTypes(TranslationUnit unit) {
		/*//collect all definitions
		val definitions = new HashMap<String, DefinitionData>()
		for(Definition definition: unit.definitions) {
			val data = new DefinitionData(definition)
			definitions.put(definition.name, data)
			switch(definition) {
				StructDefinition: data.definitionType = DefinitionType.STRUCT
				EnumDefinition: data.definitionType = DefinitionType.ENUM
				InterfaceDefinition: data.definitionType = DefinitionType.INTERFACE
				TypeDefinition:
					switch((definition as TypeDefinition).definition) {
						EnumInlineDefinition: data.definitionType = DefinitionType.ENUM
						StructInlineDefinition: data.definitionType = DefinitionType.STRUCT
						BasicType:
							switch((definition as BasicType).name) {
								case "integer": data.definitionType = DefinitionType.INTEGER
								case "string": data.definitionType = DefinitionType.STRING
								case "number": data.definitionType = DefinitionType.NUMBER
								case "boolean": data.definitionType = DefinitionType.BOOLEAN
								case "any": data.definitionType = DefinitionType.ANY
								case "null": data.definitionType = DefinitionType.NULL
								case "identifier": data.definitionType = DefinitionType.STRING
							}
						DictionaryType: data.definitionType = DefinitionType.DICTIONARY
						ListType: data.definitionType = DefinitionType.LIST
						TupleType: data.definitionType = DefinitionType.TUPLE
						NullableType: data.nullable = true
					}
			}
		}*/
	}
	
	private def getStructs(TranslationUnit unit) {
		val structs = new HashMap<String, StructData>()
		for(Definition definition: unit.definitions) {
			switch(definition) {
				StructDefinition: structs.put(definition.name, new StructData(definition, definition.abstract, definition.superType, definition.body))
				/*TypeDefinition: 
					if(definition.definition instanceof StructInlineDefinition) {
						val inline = definition.definition as StructInlineDefinition
						structs.put(definition.name, new StructData(definition, inline.abstract, inline.superType, inline.body))	
					}*/
			}
		}
		return structs
	}
	
	private def checkStructMembersNotShadowed(StructData struct, Map<String, StructData> structs) {
		val members = new HashMap<String, StructMember>()
		for(StructMember member: struct.body.members)
			members.put(member.name, member)
		var parent = if(struct.superType == null || !structs.containsKey(struct.superType.name)) null else structs.get(struct.superType.name)
		while(parent != null) {
			for(StructMember member: parent.body.members)	
				if(members.containsKey(member.name)) {
					val original = members.get(member.name)
					error("'"+struct.definition.name+"."+member.name+"' overrides '"+parent.definition.name+"."+member.name+"'.", original, JsonSchemaDslPackage.Literals::STRUCT_MEMBER__NAME);
				}
			parent = if(parent.superType == null || !structs.containsKey(parent.superType.name)) null else structs.get(parent.superType.name)
		}
	}
	
	@Check
	def checkStructs(TranslationUnit unit) {
		val structs = getStructs(unit)
		
		//create graph, find missing definitions
		val graph = new Graph<StructData>
		for(StructData struct: structs.values) 
			graph.addVertex(struct)
		for(StructData struct: structs.values) {
			if(struct.superType != null) {
				val superTypeName = struct.superType.name
				if(!structs.containsKey(superTypeName))
					error("There is no struct definition for '"+superTypeName+"'.", struct.superType, JsonSchemaDslPackage.Literals::STRUCT_SUPER_TYPE__NAME)
				else {
					val destination = structs.get(superTypeName)
					graph.addEdge(struct, destination)
				}
			}
		}
		
		//find cyclic inheritance
		val nonCycleStructs = new HashSet(structs.values)
		for(List<StructData> cyclicComponents: new CycleFinder(graph).findCycles())
			for(StructData struct: cyclicComponents) {
				error("Cyclic inheritance found.", struct.definition, JsonSchemaDslPackage.Literals::DEFINITION__NAME)
				nonCycleStructs.remove(struct)
			}
								
		//check members
		for(StructData struct: nonCycleStructs)
			checkStructMembersNotShadowed(struct, structs)
	}
	
	@Check
	def checkUniqueDefintionNames(TranslationUnit unit) {
		val map = new HashMap<String, List<Definition>>()
		for(Definition definition: unit.definitions) {
			val name = definition.name
			if(!map.containsKey(name))
				map.put(name, new LinkedList<Definition>())
			map.get(name).add(definition)				
		} 
		for(String name: map.keySet) {
			val definitions = map.get(name)
			if(definitions.size > 1) {
				for(Definition definition: definitions) {
					error("Type names have to be unique", definition, JsonSchemaDslPackage.Literals::DEFINITION__NAME);	
				}
			}
		}
	}
	
	private def checkUniqueEnumLiteral(EList<EnumLiteral> literals) {
		val map = new HashMap<String, List<EnumLiteral>>()
		for(EnumLiteral literal: literals) {
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
	
	@Check
	def checkUniqueNonInlineEnumLiteral(EnumDefinition definition) {
		checkUniqueEnumLiteral(definition.literals)	
	}
	
	@Check
	def checkUniqueInlineEnumLiteral(EnumType type) {
		checkUniqueEnumLiteral(type.literals)
	}
}
