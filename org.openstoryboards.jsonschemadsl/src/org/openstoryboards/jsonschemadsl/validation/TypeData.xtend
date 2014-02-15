package org.openstoryboards.jsonschemadsl.validation

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature

class TypeData {
	private TypeData reference = null
	
	private EObject object
	private EStructuralFeature feature
	private TypeKind kind
	private boolean nullable = false
	
	new(TypeData reference) {
		this.reference = reference
	}
	
	new(EObject object, EStructuralFeature feature, TypeKind kind, boolean nullable) {
		this.object = object
		this.feature = feature
		this.kind = kind
		this.nullable = nullable
	}
	
	def getObject() { if(reference==null) object else reference.object }
	def getFeature() { if(reference==null) feature else reference.feature }
	def getKind() { if(reference==null) kind else reference.kind }
	def getNullable() { if(reference==null) nullable else reference.nullable }
	
	def isReferenced() { reference!=null }
	def setKind(TypeKind value) { kind = value }
	def setNullable(boolean value) { nullable = value }
}