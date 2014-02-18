package org.openstoryboards.jsonschemadsl.generator

import java.util.LinkedList
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.BasicType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Constraint
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.DictionaryType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.EnumDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.IntegerType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.InterfaceDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.ListType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.NullableType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.NumberType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.ParenthesizedType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.ReferencedType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.RegexConstraint
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StringType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.TranslationUnit
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.TupleType
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Type
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.TypeDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StructDefinition
import java.util.HashMap
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StructMember
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.EventMember
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.FunctionMember

class JsonSchemaDslGenerator implements IGenerator {	
	//TODO pass sub struct types to struct type by name
	
	override void doGenerate(Resource resource, IFileSystemAccess fsa) {
		for(tu: resource.allContents.toIterable.filter(TranslationUnit)) {
			val uri = resource.URI.toString
			val fileName = uri.substring(0, uri.lastIndexOf(".")) + ".coffee"
			fsa.generateFile(fileName, tu.compile)
			System.out.println("generated '"+fileName+"'.")
		}
	}
 
	def compile(TranslationUnit unit) '''
	#constraints
	class RegexConstraint
		constructor: (@regex) ->

	class IntervalConstraint
		constructor: (@openLeft, @openRight, @from, @to) ->
		test: (value) =>
			if(@from?)
				if(@openLeft)
					if(value <= @from)
						return false
				else
					if(value < @from)
						return false
			if(@to?)
				if(@openRight)
					if(value >= @to)
						return false
				else
					if(value > @to)
						return false
			true		

	#base class
	class Type
		validate: (object) =>
			throw new Error("Not implemented validator!")

	#basic types
	class BooleanType extends Type
		validate: (object) =>
			typeof(object) == "boolean"

	class AnyType extends Type
		validate: (object) =>
			true

	class NullType extends Type
		validate: (object) =>
			object == null
	
	class EnumerationType extends Type
		maxValue: 0
		constructor: (values) ->
			index = 0
			maxValue = values.length
			for value in values
				this[value] = index++
		validate: (object) =>
			typeof(object) == "number" && Math.floor(object) == object && object < maxValue

	class NumberType extends Type
		constructor: (@constraint) ->
		validate: (object) =>
			typeof(object) == "number" && (!(@constraint?) || @constraint.test(object))

	class IntegerType extends NumberType
		constructor: (constraint) -> 
			super(constraint)
		validate: (object) =>
			super(object) && Math.floor(object) == object

	class StringType extends Type
		constructor: (@sizeConstraint, @regexConstraint) ->
		validate: (object) =>
			if(typeof(object) != "string")
				return false
			if(@regexConstraint?)
				if(!@regexConstraint.regex.test(object))
					return false
			(!(@sizeConstraint?) || @sizeConstraint.test(object.length))

	#composite types
	class NullableType extends Type
		constructor: (@type) ->
		validate: (object) =>
			object == null || @type.validate(object)

	class DictionaryType extends Type
		constructor: (@keyType, @valueType, @sizeConstraint) ->
		validate: (object) =>
			if(typeof(object)!="object")
				return false
			size = 0
			for key, value of object
				size++
				if(!@keyType.validate(key))
					return false
				if(!valueType.validate(value))
					return false
			(!(@sizeConstraint?) || @sizeConstraint.test(size))

	class ListType extends Type
		constructor: (@elementType, @sizeConstraint) ->
		validate: (object) =>
			if(!Array.isArray(object))
				return false
			for value in object
				if(!elementType.validate(value))
					return false
			(!(@sizeConstraint?) || @sizeConstraint.test(object.length))

	class TupleType extends Type
		constructor: (@tupleTypes) ->
		validate: (object) =>
			if(!Array.isArray(object))
				return false
			if(@tupleTypes.length != object.length)
				return false
			index = 0
			for tupleType in @tupleTypes
				value = object[index++]
				if(!tupleType.validate(value))
					return false
			true

	class StructType extends Type		
		constructor: (@name, @isAbstract, @superType, @members) ->
		validate: (object, isSubClass) =>
			if(typeof(object) != "object")
				return false
			if(typeof(isSubClass) == "boolean" && isSubClass)
				if(@isAbstract)
					return false
			else
				if(object["$type"] != @name)
					return false
			if(@superType? && !@superType.validate(object, true))
				return false
			for name, type of @members
				if(!object[name]?)
					return false
				if(type.validate(object[name]))
					return false
			true

	class ProxyType extends Type
		constructor: -> @type = null
		setType: (@type) =>
		validate: (object) =>
			if(@type == null)
				throw new Error("No type assigned to proxy!")
			@type.validate(object)

	class ClientEventHandler
		constructor: (@name, @implementation, @parameters) ->
		run: (object, parameters) =>
			index = 0
			for name, type of @parameters
				value = parameters[index]
				if(!type.validate(value))
					throw new Error("Event '"+@name+" received bad message format ("+(index+1)+". parameter '"+name+"'): "+JSON.stringify(value))
				index++
			if(@implementation?)
				@implementation.apply(object, parameters)
			else
				throw new Error("Please implement event '"+@name+"'.")

	class ServerFunctionHandler
		constructor: (@name, @implementation, @parameters, @returnType) ->
		run: (object, parameters) =>
			index = 0
			for name, type of @parameters
				value = parameters[index]
				if(!type.validate(value))
					throw new Error("Function '"+@name+" received bad message format ("+(index+1)+". parameter '"+name+"'): "+JSON.stringify(value))
				index++
			if(@implementation?)
				returnValue = @implementation.apply(object, parameters)
				if(@returnType? && !@returnType.validate(returnValue))
					throw new Error("Function call of '"+@name+"' return bad message format: "+JSON.stringify(returnValue))
				return returnValue
			else
				throw new Error("Please implement function '"+@name+"'.")
	
	class Socket
	
	class Server
		constructor: ->
			@functionHandlers = {}
		receive: (socket, obj) =>
			try
				switch obj.type
					when "functionCall"
						seqNo = obj.sequenceNumber
						fname = obj.functionName
						params = obj.parameters;
						params.unshift(socket);
						params.push((err, result) ->
							if(err) 
								answer = {
									type: "functionError",
									sequenceNumber: seqNo,
									errorMessage: err.message
								} 
							else 
								answer = {
									type: "functionReturn",
									sequenceNumber: seqNo,
									returnValue: result
								}
							socket.send(answer)
						)
						@functionHandlers[fname].run(this, params)
						true
			catch ex
				return false
			return false
	
	class Client
		constructor:  ->
			@eventHandlers = {}
			@callbacks = {}
			@sequenceNumber = 0
		receive: (obj) =>
			try
				switch obj.type
					when "functionError"
						seqNo = obj.sequenceNumber
						if(!(@callbacks[seqNo]?))
							return false
						callback = @callbacks[seqNo]
						delete @callbacks[seqNo]
						callback && callback(new Error(obj.errorMessage))
						return true
					when "functionReturn"
						seqNo = obj.sequenceNumber
						if(!(@callbacks[seqNo]?))
							return false
						callback = @callbacks[seqNo]
						delete @callbacks[seqNo]
						callback && callback(null, obj["returnValue"])
						return true
					when "eventCall"
						eventName = obj.eventName
						params = obj.parameters
						if(!(@eventHandlers[eventName]?))
							return false
						@eventHandlers[eventName].run(this, params)
						return true
			catch ex
				console.log(ex)
				return false
			false
	
	types = {}
	
	#enumerations
	«FOR enumDefinition: unit.definitions.filter(EnumDefinition)»
	types.«enumDefinition.name» = new EnumerationType([«enumDefinition.literals.map[lit | "\""+lit.name+"\""].join(", ")»])
	«ENDFOR»
	
	#proxies
	«FOR definition: unit.definitions.filter[d | !(d instanceof EnumDefinition || d instanceof InterfaceDefinition)]»
	types.«definition.name» = new ProxyType()
	«ENDFOR»
	
	#typedefs
	«FOR definition: unit.definitions.filter(TypeDefinition)»
	types.«definition.name».setType(«definition.type.compile»)
	«ENDFOR»
	
	#structs
	«FOR definition: unit.definitions.filter(StructDefinition)»
	types.«definition.name».setType(«definition.compile»)
	«ENDFOR»
	
	#interfaces
	«FOR definition: unit.definitions.filter(InterfaceDefinition)»
	«definition.compile»
	«ENDFOR»
	
	module.exports = types
	'''
	
	def compile(InterfaceDefinition definition) {
		val name = definition.name
		'''
		#BEGIN '«name»' interface
		class «name»Server extends Server
			constructor: (functionImplementations) ->
				super()
				«FOR function: definition.members.filter(FunctionMember)»
				@functionHandlers.«function.name» = new ServerFunctionHandler("«function.name»", functionImplementations.«function.name», {
					«FOR parameter: function.parameters»
					«parameter.name»: «parameter.type.compile»
					«ENDFOR»		
				}, «if(function.returnType == null) "null" else function.returnType.compile »)
				«ENDFOR»
			«FOR event: definition.members.filter(EventMember)»
			«event.name»: (socket, «event.parameters.map[p|p.name].join(", ")») =>
			«ENDFOR»
		
		class «name»Client extends Client
			constructor: (eventImplementations, @send) ->
				super()
				«FOR event: definition.members.filter(EventMember)»
				@eventHandlers.«event.name» = new ClientEventHandler("«event.name»", eventImplementations.«event.name», {
					«FOR parameter: event.parameters»
					«parameter.name»: «parameter.type.compile»
					«ENDFOR»		
				})
				«ENDFOR»
			«FOR function: definition.members.filter(FunctionMember)»
			«function.name»: («function.parameters.map[p|p.name].join(", ")», callback) =>
				if(arguments.length != «function.parameters.size + 1»
					|| typeof(arguments[«function.parameters.size»]) != "function"
				) throw new Error("Usage: function «function.name»(«function.parameters.map[p|p.name].join(", ")», callback)")
				
				seqNo = @sequenceNumber++
				paramsList = []
				«IF function.parameters.size > 0»
				for i in [1..«function.parameters.size»]
					paramsList.push(arguments[i-1])
				«ENDIF»
				@callbacks[seqNo] = arguments[«function.parameters.size»]
				@send({
					type: "functionCall",
					sequenceNumber: seqNo,
					functionName: "«function.name»",
					parameters: paramsList
				})
			«ENDFOR»
		
		types.«name» = {
			Client: «name»Client,
			Server: «name»Server,
		}
		#END '«name»' interface
		'''
	}
	
	def compile(StructDefinition definition) {
		val superType = if(definition.superType != null) '''types.«definition.superType.name»''' else "null"
		val members = new LinkedList<String>()
		for(StructMember member: definition.members)
			members.add(member.name+": "+member.type.compile)
		'''new StructDefinition("«definition.name»", «definition.abstract», «superType», {«members.join(", ")»})'''
	}
	
	def compile(Constraint constraint) {
		if(constraint == null)
			return "null"
		val openLeft = constraint.left.bracket.equals("(")
		val openRight = constraint.right.bracket.equals(")")
		val from = if(constraint.from != null) constraint.from.value else null
		val to = if(constraint.to != null) constraint.to.value else null
		'''new IntervalConstraint(«openLeft», «openRight», «from», «to»)'''
	}
	def compile(RegexConstraint constraint) {
		if(constraint == null)
			return "null"
		'''new RegexConstraint(«constraint.pattern»)'''
	}
	
	def String compile(Type type) {
		switch(type) {
			//basic types
			BasicType:
				switch((type as BasicType).name) {
					case "boolean": '''new BooleanType()'''
					case "any": '''new AnyType()'''
					case "null": '''new NullType()'''
				}
			IntegerType: '''new IntegerType(«(type as IntegerType).constraint.compile»)'''
			NumberType: '''new NumberType(«(type as NumberType).constraint.compile»)'''
			StringType: '''new StringType(«(type as StringType).constraint.compile», «(type as StringType).regexConstraint.compile»)'''
			
			//composite types
			NullableType: '''new NullableType(«(type as NullableType).type.compile»)'''
			DictionaryType: {
				val dictionary = type as DictionaryType 
				val key = dictionary.keyType.compile
				val value = dictionary.valueType.compile
				val constraint = dictionary.constraint.compile
				'''new DictionaryType(«key», «value», «constraint»)'''
			}
			ListType: {
				val list = type as ListType 
				val element = list.elementType.compile
				val constraint = list.constraint.compile
				'''new ListType(«element», «constraint»)'''
			}
			TupleType: {
				val tuple = type as TupleType 
				val list = new LinkedList<String>()
				for(Type tupleType : tuple.types)
					list.add(tupleType.compile)
				'''new TupleType([«list.join(",")»])'''
			}
			
			ParenthesizedType: (type as ParenthesizedType).type.compile
			ReferencedType: '''types.«(type as ReferencedType).name»'''
		}	
	}
}
