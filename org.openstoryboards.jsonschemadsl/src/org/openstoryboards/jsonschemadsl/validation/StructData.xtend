package org.openstoryboards.jsonschemadsl.validation

import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StructBodyDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Definition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StructSuperType

class StructData {
	private Definition definition;
	private boolean isAbstract;
	private StructSuperType superType;
	private StructBodyDefinition body;
	
	new(Definition definition, boolean isAbstract, StructSuperType superType, StructBodyDefinition body) {
		this.definition = definition
		this.isAbstract = isAbstract
		this.superType = superType
		this.body = body
	}
	
	def getDefinition() { return definition }
	def getAbstract() { return isAbstract }
	def	getSuperType() { return superType }
	def getBody() { return body }
}