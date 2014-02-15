package org.openstoryboards.jsonschemadsl.validation

import org.omg.CORBA.StructMember
import java.util.List

class StructData {
	public boolean isAbstract
	public StructData superType
	public List<StructMember> members
	
	new(boolean isAbstract, StructData superType, List<StructMember> members) {
		this.isAbstract = isAbstract
		this.superType = superType
		this.members = members
	}
}