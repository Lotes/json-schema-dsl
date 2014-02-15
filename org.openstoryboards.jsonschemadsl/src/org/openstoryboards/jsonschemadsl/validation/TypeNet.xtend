package org.openstoryboards.jsonschemadsl.validation

import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Definition
import java.util.Map
import java.util.HashSet
import java.util.HashMap
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.JsonSchemaDslPackage
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Type
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.TypeDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.InterfaceDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StructDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.InterfaceMember
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.EventMember
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.FunctionMember
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Parameter

class TypeNet {
	private Map<String, Definition> definitions = new HashMap<String, Definition>();
	private HashMap<EObject, Pair<EObject, EStructuralFeature>> objects = new HashMap<EObject, Pair<EObject, EStructuralFeature>>()
	private Graph<Pair<EObject, EStructuralFeature>> graph = new Graph<Pair<EObject, EStructuralFeature>>()
		
	def addDefinition(Definition definition) {
		definitions.put(definition.name, definition)
		objects.put(definition, new Pair(definition, JsonSchemaDslPackage.Literals::DEFINITION__NAME))
	}
	
	private def resolveType(EObject parent, Type type) {
		/*val object = new Pair<EObject, EStructuralFeature>(type, JsonSchemaDslPackage.Literals::TYPE)
		objects.put(type, object)*/
	}
	
	private def resolveStruct(StructDefinition structDefinition) {
		
	}
	
	private def resolveInterface(InterfaceDefinition interfaceDefinition) {
		for(InterfaceMember member : interfaceDefinition.members) {
			/*switch(member) {
				EventMember:
					for(Parameter parameter: (member as EventMember).parameters)
						
				FunctionMember:
			}*/
		}
	}
	
	def resolveTypes() {
		for(Definition definition: definitions.values) {
			val object = objects.get(definition)
			graph.addVertex(object)
			switch(definition) {
				TypeDefinition: resolveType(definition, (definition as TypeDefinition).type)
				StructDefinition: resolveStruct(definition as StructDefinition)
				InterfaceDefinition: resolveInterface(definition as InterfaceDefinition)
			}
		}	
		return graph
	}
}