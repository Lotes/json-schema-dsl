package org.openstoryboards.jsonschemadsl.validation

import org.eclipse.emf.ecore.EObject

class TypeErrorCallback {
	private JsonSchemaDslValidator validator
	private String message
	new(JsonSchemaDslValidator validator, String message) {
		this.validator = validator
		this.message = message
	}
	def void callback(TypeData typeData) {
		validator.error(typeData, message)
	}	
}