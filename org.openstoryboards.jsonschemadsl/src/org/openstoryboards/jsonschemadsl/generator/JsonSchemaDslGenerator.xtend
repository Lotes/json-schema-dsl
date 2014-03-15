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
import java.util.Set
import java.util.HashSet
import java.util.Map

class JsonSchemaDslGenerator implements IGenerator {	
	private val typesModuleName = "JsonSchemaTypes"
	private val typesModuleFileName = typesModuleName + ".coffee"
	
	override void doGenerate(Resource resource, IFileSystemAccess fsa) {
		val uri = resource.URI.toString.replace("\\", "/")
		
		//generated types file
		val typesFileName = 
			if(uri.lastIndexOf("/") > -1)
				uri.substring(0, uri.lastIndexOf("/")) + "/" + typesModuleFileName
			else
				typesModuleFileName
		fsa.generateFile(typesFileName, typesModule())
		System.out.println("generated '"+typesFileName+"'")
		
		//generate schema file
		val fileName = uri.substring(0, uri.lastIndexOf(".")) + ".coffee"
		for(tu: resource.allContents.toIterable.filter(TranslationUnit)) {
			fsa.generateFile(fileName, tu.compile)
			System.out.println("generated '"+fileName+"'.")
		}
	}
	
	private def typesModule() '''
	#validation helper
	class ValidationError
		constructor: (@path, @message) ->
		
	class ValidationResult
		constructor: ->
			@errors = []
		ok: -> !@hasErrors()
		hasErrors: -> @errors.length > 0
		addError: (path, message) -> 
			@errors.push(new ValidationError(path, message))
		addResult: (result) ->
			for error in result.errors
				@errors.push(error)
	
	#constraints
	class RegexConstraint
		constructor: (@regex) ->
		validate: (str, path) ->
			result = new ValidationResult()
			if(!@regex.test(str))
				result.addError(path, "String '"+str+"' does not match regular expression constraint.")
			result
			

	class IntervalConstraint
		constructor: (@openLeft, @openRight, @from, @to) ->
		validate: (value, path) ->
			result = new ValidationResult()
			if(@from?)
				if(@openLeft)
					if(value <= @from)
						result.addError(path, "Value "+value+" goes below or equal the lower limit "+@from+".")
				else
					if(value < @from)
						result.addError(path, "Value "+value+" goes below the lower limit "+@from+".")
			if(@to?)
				if(@openRight)
					if(value >= @to)
						result.addError(path, "Value "+value+" goes above or equal the upper limit "+@to+".")
				else
					if(value > @to)
						result.addError(path, "Value "+value+" goes above the upper limit "+@to+".")
			result

	#base class
	class Type
		constructor: ->
		validate: (object, path) ->

	#basic types
	class BooleanType extends Type
		constructor: ->
		validate: (object, path) ->
			result = new ValidationResult()
			if(typeof(object) != "boolean")
				result.addError(path, "Value is not a boolean as required.");
			result

	class AnyType extends Type
		constructor: ->
		validate: (object, path) -> #no error possible, every value is allowed
			new ValidationResult()

	class NullType extends Type
		constructor: ->
		validate: (object, path) ->
			result = new ValidationResult()
			if(object != null)
				result.addError(path, "Value is not null as required.")
			result
	
	class EnumerationType extends Type
		constructor: (values) -> 
			index = 0
			@maxValue = values.length
			for value in values
				this[value] = index++
		validate: (object, path) ->
			result = new ValidationResult()
			if(typeof(object) != "number" || Math.floor(object) != object)
				result.addError(path, "Value is not an integer as required.")
			else if(object < 0 || object >= @maxValue)
				result.addError(path, "Enumeration value lies not in interval [0, "+@maxValue+").")
			result

	class NumberType extends Type
		constructor: (@constraint) -> 
		validate: (object, path) ->
			result = new ValidationResult()
			if(typeof(object) != "number")
				result.addError(path, "Value is not numeric as required.")
			else if(@constraint?)
				result.addResult(@constraint.validate(object, path))
			result

	class IntegerType extends NumberType
		constructor: (constraint) -> 
			super(constraint)
		validate: (object, path) ->
			result = new ValidationResult()
			result.addResult(super(object, path)) 
			if(!result.hasErrors() && Math.floor(object) != object)
				result.addError(path, "Value is not an integer as required.")
			result

	class StringType extends Type
		constructor: (@sizeConstraint, @regexConstraint) ->
		validate: (object, path) ->
			result = new ValidationResult()
			if(typeof(object) != "string")
				result.addError(path, "Value is not a string as required.")
			else if(@regexConstraint?)
				result.addResult(@regexConstraint.validate(object, path))
			if(@sizeConstraint?)
				result.addResult(@sizeConstraint.validate(object.length), path+"#length")
			result

	#composite types
	class NullableType extends Type
		constructor: (@type) ->
		validate: (object, path) ->
			result = new ValidationResult()
			if(object != null)
				result.addResult(@type.validate(object, path))
			result

	class DictionaryType extends Type
		constructor: (@keyType, @valueType, @sizeConstraint) ->
		validate: (object, path) ->
			result = new ValidationResult()
			if(typeof(object)!="object")
				result.addError(path, "Value is not an object as required.")
				return result
			size = 0
			for key, value of object
				size++
				result.addResult(@keyType.validate(key, path+".<"+key+">"))
				result.addResult(@valueType.validate(value, path+"."+key))
			if(@sizeConstraint?) 
				result.addResult(@sizeConstraint.validate(size, path+"#length"))
			result

	class ListType extends Type
		constructor: (@elementType, @sizeConstraint) ->
		validate: (object, path) ->
			result = new ValidationResult()
			if(!Array.isArray(object))
				result.addError(path, "Value is not an array as required.");
				return result
			for value, index in object
				result.addResult(@elementType.validate(value, path+"["+index+"]"))
			if(@sizeConstraint?)
				result.addResult(@sizeConstraint.validate(object.length, path+"#length"))
			result

	class TupleType extends Type
		constructor: (@tupleTypes) ->
		validate: (object, path) ->
			result = new ValidationResult()
			if(!Array.isArray(object))
				result.addError(path, "Value is not an array as required.")
				return result
			if(@tupleTypes.length != object.length)
				result.addError(path, "Tuple must contain exactly "+@tupleTypes.length+" values.")
				return result
			index = 0
			for tupleType in @tupleTypes
				value = object[index++]
				result.addResult(tupleType.validate(value), path+"["+index+"]")
			result

	class StructType extends Type		
		constructor: (@name, @isAbstract, @members, @subStructs) ->
		validate: (object, path) ->
			result = new ValidationResult()
			if(typeof(object) != "object")
				result.addError(path, "Value is not an object as required.")
				return result
			typeName = object["$type"]
			if(typeName != @name)
				if(@subStructs[typeName]?)
					result.addResult(@subStructs[typeName].validate(object, path))
				else
					result.addError(path, "Object has unknown struct type '"+typeName+"'.")
			else
				if(@isAbstract)
					result.addError(path, "Cannot instantiate object of abstract struct type '"+typeName+"'.")
				for name, type of @members
					if(!object[name]?)
						result.addError(path+"."+name, "Field is not defined.")
					else 
						result.addResult(type.validate(object[name], path+"."+name))
			result

	class ProxyType extends Type
		constructor: -> @type = null
		setType: (@type) ->
		validate: (object, path) ->
			result = new ValidationResult()
			if(@type == null)
				result.addError(path, "No type assigned to proxy.")
			else
				result.addResult(@type.validate(object, path))
			result

	class EventHandler
		constructor: (@name, @parameters) ->
		validateParameters: (parameters) ->
			result = new ValidationResult()
			index = 0
			for name, type of @parameters
				value = parameters[index]
				result.addResult(type.validate(value, @name+"()#parameter"+index))
				index++
			result
		run: (implementation, object, parameters) ->
			if(implementation?)
				implementation.apply(object, parameters)
			else
				throw new Error("Please implement event '"+@name+"'.")

	class FunctionHandler extends EventHandler
		constructor: (name, parameters, @returnType) ->
			super(name, parameters)
		validateReturnValue: (returnValue) ->
			if(@returnType == null)
				new ValidationResult()
			else
				@returnType.validate(returnValue, @name+"()#returnValue")
		run: (implementation, object, parameters) ->
			if(implementation?)
				implementation.apply(object, parameters)
			else
				throw new Error("Please implement function '"+@name+"'.")
	
	class Stub
		constructor: (@eventHandlers, @functionHandlers, @implementations) ->
			@send = implementations.send

	class ServerStub extends Stub
		constructor: (events, functions, implementations) ->
			super(events, functions, implementations)
		receive: (socket, obj) ->
			if(!(@send?))
				throw new Error("Please implement function send(socketId, object).")
			try
				switch obj.type
					when "functionCall"
						seqNo = obj.sequenceNumber
						try
							fname = obj.functionName
							handler = @functionHandlers[fname]
							params = obj.parameters;
							
							validationResult = handler.validateParameters(params)
							if(!validationResult.ok())
								first = validationResult.errors[0]
								throw new Error("Bad format at '"+first.path+"': "+first.message)
							
							params.unshift(socket);
							params.push((err, result) =>
								if(err) 
									@send(socket, {
										type: "functionError",
										sequenceNumber: seqNo,
										errorMessage: err.message
									})
								else
									validationResult = handler.validateReturnValue(result)
									if(validationResult.ok())
										@send(socket, {
											type: "functionReturn",
											sequenceNumber: seqNo,
											returnValue: result
										})
									else
										first = validationResult.errors[0];
										@send(socket, {
											type: "functionError",
											sequenceNumber: seqNo,
											errorMessage: "Bad format at '"+first.path+"': "+first.message
										})
							)
							handler.run(@implementations[fname], this, params)
						catch innerException
							@send(socket, {
								type: "functionError",
								sequenceNumber: seqNo,
								errorMessage: innerException.message
							})
			catch ex
				console.log("server error: "+ex.message)
	
	class ClientStub extends Stub
		constructor: (events, functions, implementations) ->
			super(events, functions, implementations)
			@callbacks = {}
			@sequenceNumber = 0
		receive: (obj) ->
			try
				switch obj.type
					when "functionError"
						seqNo = obj.sequenceNumber
						if(!(@callbacks[seqNo]?))
							console.log("client error: unhandled message: "+JSON.stringify(obj))
							return
						callback = @callbacks[seqNo]
						delete @callbacks[seqNo]
						callback && callback(new Error(obj.errorMessage))
					when "functionReturn"
						seqNo = obj.sequenceNumber
						if(!(@callbacks[seqNo]?))
							console.log("client error: unhandled message: "+JSON.stringify(obj))
							return
						callback = @callbacks[seqNo]
						delete @callbacks[seqNo]
						callback && callback(null, obj["returnValue"])
					when "eventCall"
						eventName = obj.eventName
						params = obj.parameters
						if(!(@eventHandlers[eventName]?))
							return
						@eventHandlers[eventName].run(@implementations[eventName], this, params)
			catch ex
				console.log(ex.message)
	
	module.exports = {
		RegexConstraint: RegexConstraint,
		IntervalConstraint: IntervalConstraint, 
		ValidationError: ValidationError,
		ValidationResult: ValidationResult,
		
		Type: Type,
		BooleanType: BooleanType,
		AnyType: AnyType,
		NullType: NullType,
		EnumerationType: EnumerationType,
		NumberType: NumberType,
		IntegerType: IntegerType,
		StringType: StringType,
		NullableType: NullableType,
		DictionaryType: DictionaryType,
		ListType: ListType,
		TupleType: TupleType,
		StructType: StructType,
		ProxyType: ProxyType,
		
		EventHandler: EventHandler,
		FunctionHandler: FunctionHandler,

		ServerStub: ServerStub,
		ClientStub: ClientStub
	}
	'''
 
	def compile(TranslationUnit unit) {
		val structs = new HashMap<String, StructDefinition>()
		val structMembers = new HashMap<String, Set<StructMember>>();
		val subStructs = new HashMap<String, Set<String>>()
		val definitions = unit.definitions.filter(StructDefinition)
		for(StructDefinition struct: definitions) {
			structs.put(struct.name, struct)
			subStructs.put(struct.name, new HashSet<String>())
			subStructs.get(struct.name).add(struct.name)
			structMembers.put(struct.name, new HashSet<StructMember>())	
		}
		for(StructDefinition struct: definitions) {
			val subName = struct.name
			val members = structMembers.get(subName)
			var current = struct
			while(current != null) {
				for(StructMember member: current.members)	
					members.add(member)
					
				val superName = current.name
				subStructs.get(superName).add(subName)
				
				current = if(current.superType != null) structs.get(current.superType.name) else null
			}
		}
		'''
		common = require("./«typesModuleName»")
		RegexConstraint = common.RegexConstraint
		IntervalConstraint = common.IntervalConstraint
		ValidationError = common.ValidationError
		ValidationResult = common.ValidationResult
		
		Type = common.Type
		BooleanType = common.BooleanType
		AnyType = common.AnyType
		NullType = common.NullType
		EnumerationType = common.EnumerationType
		NumberType = common.NumberType
		IntegerType = common.IntegerType
		StringType = common.StringType
		NullableType = common.NullableType
		DictionaryType = common.DictionaryType
		ListType = common.ListType
		TupleType = common.TupleType
		StructType = common.StructType
		ProxyType = common.ProxyType
		
		EventHandler = common.EventHandler
		FunctionHandler = common.FunctionHandler
		ServerStub = common.ServerStub
		ClientStub = common.ClientStub
		
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
		types.«definition.name».setType(«compile(definition, structMembers.get(definition.name), subStructs.get(definition.name))»)
		«ENDFOR»
		
		#interfaces
		«FOR definition: unit.definitions.filter(InterfaceDefinition)»
		«definition.compile»
		«ENDFOR»
		
		module.exports = types
		'''
	}
	
	def compileForServer(EventMember event) {
		val parameters = new LinkedList<String>(event.parameters.map[p|p.name]);
		parameters.addFirst("socket");
		'''
		«event.name»: («parameters.join(", ")») ->
			if(!(@send?))
				throw new Error("Please implement function 'send(socket, object)'.")
			if(arguments.length != «event.parameters.size + 1») 
				throw new Error("Usage: event «event.name»(«parameters.join(", ")»)")
			parameters = [«event.parameters.map[p|p.name].join(", ")»]
			result = @eventHandlers["«event.name»"].validateParameters(parameters)
			if(!result.ok())
				throw new Error("Bad format at '"+result.errors[0].path+"': "+result.errors[0].message)
			@send(socket, {
				type: "eventCall",
				eventName: "«event.name»",
				parameters: parameters
			})
		'''
	}
	
	def compileForClient(FunctionMember function) {
		val parameters = new LinkedList<String>(function.parameters.map[p|p.name]);
		parameters.addLast("callback");
		'''
		«function.name»: («parameters.join(", ")») ->
			if(!(@send?))
				throw new Error("Please implement function 'send(object)'.")
			if(arguments.length != «function.parameters.size + 1» || typeof(arguments[«function.parameters.size»]) != "function") 
				throw new Error("Usage: function «function.name»(«parameters.join(", ")»)")
		
			paramsList = []
			«IF function.parameters.size > 0»
			for i in [1..«function.parameters.size»]
				paramsList.push(arguments[i-1])
			«ENDIF»
			
			result = @functionHandlers["«function.name»"].validateParameters(paramsList)
			if(!result.ok())
				callback(new Error("Bad format at '"+result.errors[0].path+"': "+result.errors[0].message))
			else
				seqNo = @sequenceNumber++
				@callbacks[seqNo] = arguments[«function.parameters.size»]
				@send({
					type: "functionCall",
					sequenceNumber: seqNo,
					functionName: "«function.name»",
					parameters: paramsList
				})
		'''
	}
	
	def compile(InterfaceDefinition definition) {
		val name = definition.name
		'''
		#BEGIN '«name»' interface
		«name»EventHandlers = {}
		«FOR event: definition.members.filter(EventMember)»
		«name»EventHandlers.«event.name» = new EventHandler("«event.name»", {
			«FOR parameter: event.parameters»
			«parameter.name»: «parameter.type.compile»
			«ENDFOR»		
		})
		«ENDFOR»

		«name»FunctionHandlers = {}
		«FOR function: definition.members.filter(FunctionMember)»
		«name»FunctionHandlers.«function.name» = new FunctionHandler("«function.name»", {
			«FOR parameter: function.parameters»
			«parameter.name»: «parameter.type.compile»
			«ENDFOR»		
		}, «if(function.returnType == null) "null" else function.returnType.compile»)
		«ENDFOR»

		class «name»ServerStub extends ServerStub
			constructor: (implementations) ->
				super(«name»EventHandlers, «name»FunctionHandlers, implementations)
			«FOR event: definition.members.filter(EventMember)»
			«event.compileForServer»
			«ENDFOR»
		
		class «name»ClientStub extends ClientStub
			constructor: (implementations) ->
				super(«name»EventHandlers, «name»FunctionHandlers, implementations)
			«FOR function: definition.members.filter(FunctionMember)»
			«function.compileForClient»
			«ENDFOR»
		
		types.«name» = {
			ClientStub: «name»ClientStub,
			ServerStub: «name»ServerStub,
		}
		#END '«name»' interface
		'''
	}
	
	def compile(StructDefinition definition, Set<StructMember> structMembers, Set<String> subStructs) {
		val members = new LinkedList<String>()
		for(StructMember member: structMembers)
			members.add(member.name+": "+member.type.compile)
		'''new StructType("«definition.name»", «definition.abstract», {«members.join(", ")»}, {«subStructs.map[s|s+": types."+s].join(",")»})'''
	}
	
	def compile(Constraint constraint) {
		if(constraint == null)
			return "null"
		val openLeft = constraint.left.bracket.equals("(")
		val openRight = constraint.right.bracket.equals(")")
		val from = if(constraint.from != null) constraint.from.value else "null"
		val to = if(constraint.to != null) constraint.to.value else "null"
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
