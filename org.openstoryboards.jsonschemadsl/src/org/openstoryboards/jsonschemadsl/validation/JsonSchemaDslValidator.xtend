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
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.InterfaceDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.TypeDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.RegexConstraint
import java.util.regex.Pattern
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Constraint

class JsonSchemaDslValidator extends AbstractJsonSchemaDslValidator {
/*
 * unique event & function parameter names
 */

	/*private def getStructs(TranslationUnit unit) {
		val structs = new HashMap<String, StructData>()
		for(Definition definition: unit.definitions) {
			switch(definition) {
				StructDefinition: structs.put(definition.name, new StructData(definition, definition.abstract, definition.superType, definition.body))
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
	}*/
	
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
		//filter unique definitions, throw errors on duplicates
		val net = new TypeNet()
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
	
		//resolve types
		val graph = net.resolveTypes()
		
		//find cyclic inheritance
		/*for(List<StructData> cyclicComponents: new CycleFinder(graph).findCycles())
			for(StructData struct: cyclicComponents) {
				error("Cyclic inheritance found.", struct.definition, JsonSchemaDslPackage.Literals::DEFINITION__NAME)
			}*/
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
		val from = constraint.from.value
		if(constraint.to != null) {
			val to = constraint.to.value
			if(from > to)
				error("Upper limit must be bigger or equal than lower limit.", constraint, JsonSchemaDslPackage.Literals::CONSTRAINT__FROM)
			else if(from == to && (openLeft || openRight))
				error("Constraint results in empty type.", constraint, JsonSchemaDslPackage.Literals::CONSTRAINT__FROM)
		} else {
			if(openLeft || openRight)
				error("Constraint results in empty type.", constraint, JsonSchemaDslPackage.Literals::CONSTRAINT__FROM)
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
