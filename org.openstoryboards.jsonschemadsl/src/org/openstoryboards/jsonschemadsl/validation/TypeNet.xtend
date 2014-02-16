package org.openstoryboards.jsonschemadsl.validation

import java.util.HashMap
import java.util.LinkedList
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.BasicType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Definition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.DictionaryType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.EnumDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.EventMember
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.FunctionMember
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.IntegerType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.InterfaceDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.InterfaceMember
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.JsonSchemaDslPackage
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.ListType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.NullableType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.NumberType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Parameter
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.ParenthesizedType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.ReferencedType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StringType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StructDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StructMember
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.TupleType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Type
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.TypeDefinition

class TypeNet {
	public static final String ERROR_DICTIONARY_KEY_NOT_STRING = "dictionary_key_not_string"
	public static final String ERROR_DICTIONARY_KEY_NULLABLE = "dictionary_key_nullable"
	public static final String ERROR_REFERENCED_TYPE_INTERACE = "referenced_type_interface"
	public static final String ERROR_TYPE_UNKNOWN = "type_unknown"
	public static final String ERROR_TYPE_CYCLIC_DEPENDENCY = "cyclic_dependency"
	public static final String ERROR_STRUCT_SUPER_TYPE_NOT_STRUCT = "struct_super_type_not_struct"
	public static final String ERROR_STRUCT_SUPER_TYPE_NULL = "struct_super_type_null"
	public static final String ERROR_STRUCT_MEMBER_NOT_UNIQUE = "struct_member_not_unique"
	public static final String ERROR_STRUCT_MEMBER_OVERRIDDEN = "struct_member_overridden"
	public static final String ERROR_INTERFACE_MEMBER_NOT_UNIQUE = "interface_member_not_unique"
	public static final String ERROR_PARAMETER_NOT_UNIQUE = "parameter_not_unique"
	
	private Map<String, List<TypeErrorCallback>> errorCallbacks = new HashMap<String, List<TypeErrorCallback>>()
	
	private Map<String, StructData> structs = new HashMap<String, StructData>()
	private Map<String, Definition> definitions = new HashMap<String, Definition>()
	private HashMap<EObject, TypeData> objects = new HashMap<EObject, TypeData>()
	private Graph<TypeData> graph = new Graph<TypeData>()
	
	def addDefinition(Definition definition) {
		definitions.put(definition.name, definition)
		val kind = switch(definition) {
			StructDefinition: TypeKind.STRUCT
			EnumDefinition: TypeKind.ENUM
			InterfaceDefinition: TypeKind.INTERFACE
			default: TypeKind.UNKNOWN //all other typedefs		
		}
		objects.put(definition, new TypeData(definition, JsonSchemaDslPackage.Literals::DEFINITION__NAME, kind, false))
	}
		
	def onError(String event, TypeErrorCallback cb) {
		if(!errorCallbacks.containsKey(event))
			errorCallbacks.put(event, new LinkedList<TypeErrorCallback>())
		errorCallbacks.get(event).add(cb)
	}
		
	private def triggerError(String event, TypeData data) {
		if(errorCallbacks.containsKey(event))
			for(TypeErrorCallback cb: errorCallbacks.get(event))
				cb.callback(data);
	}
	
	private def resolveTypeDefinition(TypeDefinition definition) {
		val typeData = objects.get(definition)
		val referencedTypeData = resolveType(definition.type)
		typeData.kind = referencedTypeData.kind
		typeData.nullable = referencedTypeData.nullable
		graph.addEdge(typeData, referencedTypeData)
	}
	
	private def TypeData resolveType(Type type) {
		val typeData = switch(type) {
			BasicType:
				switch((type as BasicType).name) {
					case "boolean": new TypeData(type, JsonSchemaDslPackage.Literals::BASIC_TYPE__NAME, TypeKind.BOOLEAN, false)
					case "any": new TypeData(type, JsonSchemaDslPackage.Literals::BASIC_TYPE__NAME, TypeKind.BOOLEAN, true)
					case "null": new TypeData(type, JsonSchemaDslPackage.Literals::BASIC_TYPE__NAME, TypeKind.BOOLEAN, true)
				}
			ReferencedType: resolveReferencedType(type as ReferencedType)
			DictionaryType: resolveDictionaryType(type as DictionaryType)
			ListType: resolveListType(type as ListType)
			TupleType: resolveTupleType(type as TupleType)
			NullableType: resolveNullableType(type as NullableType)
			ParenthesizedType: resolveType((type as ParenthesizedType).type)			
			IntegerType: new TypeData(type, JsonSchemaDslPackage.Literals::INTEGER_TYPE__KEYWORD, TypeKind.INTEGER, false)
			NumberType: new TypeData(type, JsonSchemaDslPackage.Literals::NUMBER_TYPE__KEYWORD, TypeKind.NUMBER, false)
			StringType: new TypeData(type, JsonSchemaDslPackage.Literals::STRING_TYPE__KEYWORD, TypeKind.STRING, false)
		}
		graph.addVertex(typeData)
		objects.put(typeData.object, typeData)
		return typeData
	}
	
	private def TypeData resolveNullableType(NullableType type) {
		val referencedTypeData = resolveType(type.type)
		val typeData = new TypeData(type, JsonSchemaDslPackage.Literals::NULLABLE_TYPE__KEYWORD, referencedTypeData.kind, true)
		graph.addVertex(typeData)
		//REMARK: no edge was created, because a nullable type has the alternative "null"
		typeData
	}
	
	private def TypeData resolveReferencedType(ReferencedType type) {
		if(definitions.containsKey(type.name)){
			val definition = definitions.get(type.name)
			val referencedTypeData = objects.get(definition)
			val typeData = new TypeData(referencedTypeData)
			if(typeData.kind == TypeKind.INTERFACE)
				triggerError(ERROR_REFERENCED_TYPE_INTERACE, new TypeData(type, JsonSchemaDslPackage.Literals::REFERENCED_TYPE__NAME, TypeKind.UNKNOWN, false))
			graph.addVertex(typeData)
			graph.addEdge(typeData, referencedTypeData)
			return typeData	
		} else {
			val typeData = new TypeData(type, JsonSchemaDslPackage.Literals::REFERENCED_TYPE__NAME, TypeKind.UNKNOWN, false)
			graph.addVertex(typeData)
			return typeData
		}
	}
	
	private def TypeData resolveDictionaryType(DictionaryType type) {
		val keyTypeData = resolveType(type.keyType)
		if(keyTypeData.kind != TypeKind.STRING)
			triggerError(ERROR_DICTIONARY_KEY_NOT_STRING, keyTypeData)
		if(keyTypeData.nullable)
			triggerError(ERROR_DICTIONARY_KEY_NULLABLE, keyTypeData)
			
		val valueTypeData = resolveType(type.valueType)
		val typeData = new TypeData(type, JsonSchemaDslPackage.Literals::DICTIONARY_TYPE__KEYWORD, TypeKind.DICTIONARY, false)
		graph.addVertex(typeData)
		graph.addEdge(typeData, keyTypeData)
		graph.addEdge(typeData, valueTypeData)
		
		return typeData		
	}
	
	private def TypeData resolveListType(ListType type) {
		val typeData = new TypeData(type, JsonSchemaDslPackage.Literals::LIST_TYPE__KEYWORD, TypeKind.LIST, false)
		graph.addVertex(typeData)
		val elementTypeData = resolveType(type.elementType)
		graph.addEdge(typeData, elementTypeData)
		return typeData
	}
	
	private def TypeData resolveTupleType(TupleType type) {
		val typeData = new TypeData(type, JsonSchemaDslPackage.Literals::TUPLE_TYPE__KEYWORD, TypeKind.TUPLE, false)
		graph.addVertex(typeData)
		for(Type component: type.types) {
			val componentTypeData = resolveType(component)
			graph.addEdge(typeData, componentTypeData)
		}
		return typeData
	}
	
	private def void resolveStructDefintion(TypeData structTypeData, StructDefinition definition) { 
		val superType = definition.superType
		val members = definition.members
		
		//members
		for(StructMember member: members) {
			val memberTypeData = resolveType(member.type)
			graph.addEdge(structTypeData, memberTypeData)
		}	
		//super type
		if(superType != null) {
			if(definitions.containsKey(superType.name)){
				val superDefinition = definitions.get(superType.name)
				val referencedTypeData = objects.get(superDefinition)
				val typeData = new TypeData(superType, JsonSchemaDslPackage.Literals::STRUCT_SUPER_TYPE__NAME, TypeKind.UNKNOWN, false)
				if(referencedTypeData.kind != TypeKind.STRUCT)
					triggerError(ERROR_STRUCT_SUPER_TYPE_NOT_STRUCT, typeData)
				else if(referencedTypeData.nullable)
					triggerError(ERROR_STRUCT_SUPER_TYPE_NULL, typeData)
				graph.addEdge(structTypeData, referencedTypeData)
			} else {
				val typeData = new TypeData(superType, JsonSchemaDslPackage.Literals::STRUCT_SUPER_TYPE__NAME, TypeKind.UNKNOWN, false)
				graph.addVertex(typeData)
				graph.addEdge(structTypeData, typeData)
			}
		}
	}
	
	private def checkStructMembers(StructData struct) {
		//collect members
		val members = new HashMap<String, List<StructMember>>()
		for(StructMember member: struct.members) {
			if(!members.containsKey(member.name))
				members.put(member.name, new LinkedList<StructMember>())
			members.get(member.name).add(member)
		}
		
		//check for duplicates
		for(String name: members.keySet) {
			val list = members.get(name)
			if(list.size > 1)
				for(StructMember member : list)
					triggerError(ERROR_STRUCT_MEMBER_NOT_UNIQUE, new TypeData(member, JsonSchemaDslPackage.Literals::STRUCT_MEMBER__NAME, TypeKind.UNKNOWN, false))
		}
			
		//check for overridden members
		var parent = struct.superType
		while(parent != null && parent != struct) {
			for(StructMember member: parent.members)	
				if(members.containsKey(member.name)) {
					val originals = members.get(member.name)
					for(StructMember original: originals)
						triggerError(ERROR_STRUCT_MEMBER_OVERRIDDEN, new TypeData(original, JsonSchemaDslPackage.Literals::STRUCT_MEMBER__NAME, TypeKind.UNKNOWN, false));
				}
			parent = parent.superType
		}
	}
	
	private def checkParameters(List<Parameter> parameters) {
		val members = new HashMap<String, List<Parameter>>()
		for(Parameter parameter : parameters) {
			resolveType(parameter.type)
			if(!members.containsKey(parameter.name))
				members.put(parameter.name, new LinkedList<Parameter>())
			members.get(parameter.name).add(parameter)
		}
		
		for(String name : members.keySet) {
			val list = members.get(name)
			if(list.size > 1)
				for(Parameter member: list)
					triggerError(ERROR_PARAMETER_NOT_UNIQUE, new TypeData(member, JsonSchemaDslPackage.Literals::PARAMETER__NAME, TypeKind.UNKNOWN, false))
		}
	}
	
	private def resolveInterface(InterfaceDefinition interfaceDefinition) {
		val members = new HashMap<String, List<InterfaceMember>>()
		for(InterfaceMember member : interfaceDefinition.members) {
			if(!members.containsKey(member.name))
				members.put(member.name, new LinkedList<InterfaceMember>())
			members.get(member.name).add(member)
			
			switch(member) {
				EventMember: {
					val event = member as EventMember
					checkParameters(event.parameters)
				}			
				FunctionMember: {
					val function = member as FunctionMember
					checkParameters(function.parameters)
					if(function.returnType != null)
						resolveType(function.returnType)
				}
			}
		}
		
		for(String name : members.keySet) {
			val list = members.get(name)
			if(list.size > 1)
				for(InterfaceMember member: list)
					triggerError(ERROR_INTERFACE_MEMBER_NOT_UNIQUE, new TypeData(member, JsonSchemaDslPackage.Literals::INTERFACE_MEMBER__NAME, TypeKind.UNKNOWN, false))
		}
	}
	
	def resolveTypes() {
		//TODO interfaces: unique parameter names
		
		//visit all types
		try {
			for(Definition definition: definitions.values) {
				val object = objects.get(definition)
				graph.addVertex(object)
				switch(definition) {
					TypeDefinition: resolveTypeDefinition(definition as TypeDefinition)
					StructDefinition: {
						val structDef = definition as StructDefinition
						resolveStructDefintion(object, structDef)
						structs.put(definition.name, new StructData(structDef, structDef.abstract, structDef.members))
					}
					InterfaceDefinition: resolveInterface(definition as InterfaceDefinition)
				}
			}		
		} catch(Exception ex) {
			System.out.println(ex.message)
			ex.printStackTrace
		}
		
		//visit unknown types
		for(TypeData typeData: objects.values)
			if(typeData.kind == TypeKind.UNKNOWN && !typeData.referenced)
				triggerError(ERROR_TYPE_UNKNOWN, typeData)
				
		//find cyclic dependencies
		val cycleGroups = new CycleFinder(graph).findCycles()
		for(List<TypeData> group: cycleGroups)
			for(TypeData typeData: group)
				triggerError(ERROR_TYPE_CYCLIC_DEPENDENCY, typeData)
				
		//check structs
		for(StructData struct : structs.values)
			if(struct.definition.superType != null) {
				val superName = struct.definition.superType.name
				if(structs.containsKey(superName)) //missing super type was detected before
					struct.superType = structs.get(superName)
			}
		for(StructData struct : structs.values)
			checkStructMembers(struct)
	}
}