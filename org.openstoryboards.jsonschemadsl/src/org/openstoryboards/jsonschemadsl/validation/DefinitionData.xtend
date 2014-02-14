package org.openstoryboards.jsonschemadsl.validation

import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.Definition

class DefinitionData {
	private DefinitionType type
	private Definition definition
	private boolean nullable = false
	new(Definition definition) {
		this.type = DefinitionType.UNKNOWN
		this.definition = definition
	}
	def getDefinition() { return definition }
	def getDefinitionType() { return type }
	def setDefinitionType(DefinitionType value) { type = value }
	def getNullable() { return nullable }
	def setNullable(boolean value) { nullable = value }
}