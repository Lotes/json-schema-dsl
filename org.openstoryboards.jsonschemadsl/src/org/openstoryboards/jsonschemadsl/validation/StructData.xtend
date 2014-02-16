package org.openstoryboards.jsonschemadsl.validation

import java.util.List
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StructDefinition
import org.openstoryboards.jsonschemadsl.jsonSchemaDsl.StructMember

class StructData {
	public boolean isAbstract
	public StructData superType
	public List<StructMember> members
	public StructDefinition definition
	
	new(StructDefinition definition, boolean isAbstract, List<StructMember> members) {
		this.definition = definition
		this.isAbstract = isAbstract
		this.superType = null
		this.members = members
	}
}