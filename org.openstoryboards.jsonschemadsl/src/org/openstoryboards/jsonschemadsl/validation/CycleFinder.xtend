package org.openstoryboards.jsonschemadsl.validation

import java.util.HashMap
import java.util.LinkedList
import java.util.List
import java.util.Map
import java.util.Stack
import org.eclipse.xtext.xbase.lib.Pair

class CycleFinder<Elem> {
	private Graph<Elem> graph;
	private int maxdfs = 0;
	
	new(Graph<Elem> graph) {
		this.graph = graph
	}
	
	def findCycles() {
		val groups = new LinkedList<List<Elem>>()
		val annotations = new HashMap<Elem, Pair<Integer, Integer>>()
		val U = new LinkedList<Elem>(graph.getVertices()) // Menge der unbesuchten Knoten
		val S = new Stack() // Stack zu Beginn leer
		while (!U.empty) { // Solange es bis jetzt unerreichbare Knoten gibt
			tarjan(groups, annotations, S, U, U.pop) // Aufruf arbeitet alle von v0 erreichbaren Knoten ab		
		}
        groups
	}

	private def void tarjan(List<List<Elem>> groups, Map<Elem, Pair<Integer, Integer>> annotations, Stack<Elem> S, List<Elem> U, Elem v) {
		//v -> (dfs, lowlink)
		annotations.put(v, new Pair<Integer,Integer>(maxdfs, maxdfs))
		maxdfs = maxdfs + 1      // Zähler erhöhen
		S.push(v)                // v auf Stack setzen
		U.remove(v)              // v aus U entfernen
		for(Elem w: graph.getDestinations(v)) { // benachbarte Knoten betrachten
			if (U.contains(w)) {
				tarjan(groups, annotations, S, U, w)            // rekursiver Aufruf
		    	val av = annotations.get(v)
		    	val aw = annotations.get(w)
		    	annotations.put(v, new Pair<Integer, Integer>(av.key, Math.min(av.value, aw.value)))
			} else if(S.contains(w)) {
				val av = annotations.get(v)
		    	val aw = annotations.get(w)
		    	annotations.put(v, new Pair<Integer, Integer>(av.key, Math.min(av.value, aw.key)))
			}
		}     
		val anno = annotations.get(v)		  
		if (anno.key == anno.value) {
			val group = new LinkedList<Elem>()
			var w = null as Elem
			do {
				w = S.pop()	
				group.add(w)
			} while(w != v)
			if(group.size > 1)
				groups.add(group)
			else {
				w = group.get(0)
				if(graph.containsEdge(w, w))
					groups.add(group)	
			}
		}
	}
}