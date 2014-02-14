package org.openstoryboards.jsonschemadsl.validation

import java.util.Set
import java.util.HashSet
import java.util.Map
import java.util.HashMap

class Graph<Elem> {
	private Set<Elem> vertices = new HashSet<Elem>()
	private Map<Elem, Set<Elem>> edges = new HashMap<Elem, Set<Elem>>()
	
	def addVertex(Elem elem) { 
		vertices.add(elem)
	}
	
	def addEdge(Elem from, Elem to) {
		if(!vertices.contains(from)) 
			addVertex(from)
		if(!vertices.contains(to))
			addVertex(to)
		if(!edges.containsKey(from))
			edges.put(from, new HashSet<Elem>())
		edges.get(from).add(to)
	}
	
	def getVertices() {
		vertices
	}
	
	def getDestinations(Elem from) {
		if(edges.containsKey(from))
			edges.get(from)
		else
			new HashSet<Elem>()
	}
	
	def containsEdge(Elem from, Elem to) {
		edges.containsKey(from) && edges.get(from).contains(to)
	}
}