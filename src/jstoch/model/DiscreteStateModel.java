package jstoch.model;


import java.util.*;

import jstoch.space.*;

public class DiscreteStateModel<T> implements StochasticModel
{
	private boolean initialized = false;
	
	// For spatial models (lattices only for now)
	private Lattice<T> space = null;
	private Lattice<Site> sites = null;
	
	// For spatial and non-spatial models: track number in each state
	private Map<T, Integer> counts;
	private int totalCount;
	
	private Class<T> tClass;
	
	private List<Transition> transitions;
	
	// For updating affected events in non-spatial models
	private Map<T, Set<Transition>> dependencyMap;
	
	// For efficient updating of affected events in spatial models
	private Map<T, Set<Transition>> transitionMap;
	private Map<T, Map<T, Set<T>>> dependencyMapSpatial;
	
	@SuppressWarnings("unchecked")
	public DiscreteStateModel(Class<T> tClass)
	{
		transitions = new ArrayList<Transition>();
		
		this.tClass = tClass;
		
		if(tClass.isEnum())
			counts = new EnumMap(tClass);
		else
			counts = new HashMap<T, Integer>();
	}

	@SuppressWarnings("unchecked")
	// TODO: break up into smaller methods
	public void initialize()
	{
		if(initialized) return;
		
		// Set up mapping between states and possible transitions from that state
		// and map from states and transitions whose rates are dependent on that state
		if(tClass.isEnum())
		{
			transitionMap = new EnumMap(tClass);
			
			if(space == null)
				dependencyMap = new EnumMap(tClass);
			else
				dependencyMapSpatial = new EnumMap(tClass);
		}
		else
		{
			transitionMap = new HashMap<T, Set<Transition>>();
			
			if(space == null)
				dependencyMap = new HashMap<T, Set<Transition>>();
			else
				dependencyMapSpatial = new HashMap<T, Map<T, Set<T>>>();
		}
		
		for(Transition transition : transitions)
		{
			if(space == null)
			{
				Set<Transition> dependentTransitions = dependencyMap.get(transition.state1);
				if(dependentTransitions == null)
				{
					dependentTransitions = new HashSet<Transition>();
					dependencyMap.put(transition.state1, dependentTransitions);
				}
				dependentTransitions.add(transition);
			}
			else
			{
				if(transitionMap.get(transition.state1) == null)
					transitionMap.put(transition.state1, new HashSet<Transition>());
				transitionMap.get(transition.state1).add(transition);
			}
			
			if(transition.reactants != null)
			{
				if(space == null)
				{
					for(T reactant : transition.reactants)
					{
						Set<Transition> dependentTransitions = dependencyMap.get(reactant);
						if(dependentTransitions == null)
						{
							dependentTransitions = new HashSet<Transition>();
							dependencyMap.put(reactant, dependentTransitions);
						}
						dependentTransitions.add(transition);
					}
				}
				else
				{
					// Create maps from the source state of a transition
					// to a map between a state and the set of all
					// destination states whose transition is dependent
					// on that state. Read that carefully, and see how it is used
					// in the event update method for efficient updating
					// of dependent events.
					Map<T, Set<T>> dependencyMapMap = dependencyMapSpatial.get(transition.state1);
					if(dependencyMapMap == null)
					{
						if(tClass.isEnum())
							dependencyMapMap = new EnumMap(tClass);
						else
							dependencyMapMap = new HashMap<T, Set<T>>();
						
						dependencyMapSpatial.put(transition.state1, dependencyMapMap);
					}
					
					for(T reactant : transition.reactants)
					{
						Set<T> dependencyMapMapSet = dependencyMapMap.get(reactant);
						if(dependencyMapMapSet == null)
						{
							if(tClass.isEnum())
								dependencyMapMapSet = (Set<T>) EnumSet.noneOf((Class)tClass);
							else
								dependencyMapMapSet = new HashSet<T>();
							
							dependencyMapMap.put(reactant, dependencyMapMapSet);
						}
						
						dependencyMapMapSet.add(transition.state2);
					}
				}
			}
		}
		
		if(space != null)
		{
			// Initialize initial space lattice
			int numRows = space.getNumRows();
			int numCols = space.getNumCols();
			
			sites = new Lattice<Site>(numRows, numCols,
					space.getBoundaryCondition(), space.getNeighborhoodType());
			
			for(int row = 0; row < numRows; row++)
			{
				for(int col = 0; col < numCols; col++)
				{
					Site site = new Site(row, col);
					site.setUpEvents();
					sites.put(site, row, col);
				}
			}
			
			// Initialize counts
			counts.clear();
			for(int row = 0; row < numRows; row++)
			{
				for(int col = 0; col < numCols; col++)
				{
					updateCounts(space.get(row, col), 1);
				}
			}
		}
		
		initialized = true;
	}
	
	public List<Event> getAllEvents()
	{
		List<Event> events = new ArrayList<Event>();
		
		if(space == null)
		{
			events.addAll(transitions);
		}
		else
		{
			int numRows = sites.getNumRows();
			int numCols = sites.getNumCols();
			for(int row = 0; row < numRows; row++)
			{
				for(int col = 0; col < numCols; col++)
				{
					events.addAll(sites.get(row, col).activeEvents.values());
				}
			}
		}
		
		return events;
	}
	
	public void setSpace(Lattice<T> space)
	{
		if(initialized) return;
		
		this.space = space;
	}
	
	public Lattice<T> getSpace()
	{
		return space;
	}
	
	public void setInitialCounts(Map<T, Integer> counts)
	{
		if(initialized) return;
		
		this.counts.clear();
		this.counts.putAll(counts);
		
		totalCount = 0;
		for(Integer count : counts.values())
		{
			totalCount += count;
		}
	}
	
	public void addTransition(T state1, T state2, T[] reactants, double rateConstant,
			DensityMethod densityMethod)
	{
		if(initialized) return;
		
		RateFunction rateFunc = new MassActionRateFunction(rateConstant,
				reactants == null ? 0 : reactants.length, densityMethod);
		Transition transition = new Transition(state1, state2, reactants, rateFunc);
		transitions.add(transition);
	}
	
	public void addTransition(T state1, T state2, T[] reactants, RateFunction rateFunction)
	{
		if(initialized) return;
		
		Transition transition = new Transition(state1, state2, reactants, rateFunction);
		transitions.add(transition);
	}
	
	/**
	 * Class representing a simple transition between states.
	 * Event interface implementation is only used in non-spatial models;
	 * spatial models use TransitionSiteEvent objects.
	 */
	private class Transition implements DiscreteStateEvent<T>
	{
		private T state1;
		private T state2;
		
		private T[] reactants;
		private RateFunction rateFunction;
		
		private Map<T, Integer> indexes;
		
		@SuppressWarnings("unchecked")
		public Transition(T state1, T state2, T[] reactants, RateFunction rateFunction)
		{
			this.state1 = state1;
			this.state2 = state2;
			this.reactants = reactants;
			this.rateFunction = rateFunction;
			
			if(tClass.isEnum())
				indexes = new EnumMap(tClass);
			else
				indexes = new HashMap<T, Integer>(reactants.length);
			
			if(reactants != null)
			{
				for(int i = 0; i < reactants.length; i++)
				{
					indexes.put(reactants[i], i);
				}
			}
		}
		
		public T getStartState()
		{
			return state1;
		}
		
		public T getEndState()
		{
			return state2;
		}
		
		public T[] getReactants()
		{
			return reactants;
		}
		
		public RateFunction getRateFunction()
		{
			return rateFunction;
		}
		
		public Integer getIndex(T reactant)
		{
			return indexes.get(reactant);
		}
		
		public double getRate()
		{
			int state1Count = getCount(state1);
			
			if(state1Count == 0) return 0.0;
			
			if(reactants == null)
			{
				return rateFunction.getRate(totalCount) * state1Count;
			}
			
			int[] populations = new int[reactants.length];
			
			for(T reactant : reactants)
			{
				populations[getIndex(reactant)] = getCount(reactant);
			}
			
			return rateFunction.getRate(totalCount, populations) * state1Count;
		}

		public void performEvent(double time, Set<Event> eventsToRemove,
				Set<Event> eventsToUpdate)
		{
			updateCounts(state1, -1);
			updateCounts(state2, 1);
			
			Set<Transition> state1Dependencies = dependencyMap.get(state1);
			if(state1Dependencies != null)
				eventsToUpdate.addAll(state1Dependencies);
			
			Set<Transition> state2Dependencies = dependencyMap.get(state2);
			if(state2Dependencies != null)
				eventsToUpdate.addAll(dependencyMap.get(state2));
		}
		
		public String toString()
		{
			return state1.toString() + "->" + state2.toString();
		}
	}
	
	public class Site
	{
		private int row;
		private int col;
		
		private Map<T, TransitionSiteEvent> activeEvents;
		
		@SuppressWarnings("unchecked")
		public Site(int row, int col)
		{
			this.row = row;
			this.col = col;
			
			if(tClass.isEnum())
				activeEvents = new EnumMap(tClass);
			else
				activeEvents = new HashMap<T, TransitionSiteEvent>();
		}
		
		private List<Site> getNeighbors()
		{
			return sites.getNeighbors(row, col);
		}
		
		private T getState()
		{
			return getState(row, col);
		}
		
		private T getState(int row, int col)
		{
			return space.get(row, col);
		}
		
		private void setUpEvents()
		{
			Set<Transition> transitions = transitionMap.get(getState());
			if(transitions != null)
			{
				for(Transition transition : transitions)
				{
					TransitionSiteEvent event = new TransitionSiteEvent(transition);
					activeEvents.put(transition.state2, event);
				}
			}
		}
		
		public class TransitionSiteEvent implements DiscreteStateLatticeEvent<T>
		{
			private Transition transition;
			
			public TransitionSiteEvent(Transition transition)
			{
				this.transition = transition;
			}
			
			public int getRow() { return row; }
			public int getCol() { return col; }
			public T getState() { return Site.this.getState(); }
			
			public double getRate()
			{
				List<Site> neighbors = getNeighbors();
				
				if(transition.reactants == null)
				{
					return transition.rateFunction.getRate(neighbors.size());
				}
				
				int[] populations = new int[transition.reactants.length];
				
				for(Site neighbor : neighbors)
				{
					Integer stateIndex = transition.getIndex(Site.this.getState(neighbor.row, neighbor.col));
					if(stateIndex != null)
						populations[stateIndex]++;
				}
				
				return transition.rateFunction.getRate(neighbors.size(), populations);
			}

			public void performEvent(double time, Set<Event> eventsToRemove,
					Set<Event> eventsToUpdate)
			{
				space.put(transition.state2, row, col);
				updateCounts(transition.state1, -1);
				updateCounts(transition.state2, 1);
				
				// Remove existing events at this site
				eventsToRemove.addAll(activeEvents.values());
				activeEvents.clear();
				
				// Add events associated with new state
				setUpEvents();
				eventsToUpdate.addAll(activeEvents.values());
				
				// Update all events dependent on from and to states
				for(Site neighbor : getNeighbors())
				{
					// Map from a state to destination states of transitions whose
					// rate depends on that state, for this neighbor
					Map<T, Set<T>> neighborDependencyMap = dependencyMapSpatial.get(neighbor.getState());
					
					if(neighborDependencyMap != null)
					{
						Set<T> destStates1 = neighborDependencyMap.get(transition.state1);
						if(destStates1 != null)
							for(T dependencyDestState : neighborDependencyMap.get(transition.state1))
								eventsToUpdate.add(neighbor.activeEvents.get(dependencyDestState));
						
						Set<T> destStates2 = neighborDependencyMap.get(transition.state2);
						if(destStates2 != null)
							for(T dependencyDestState : neighborDependencyMap.get(transition.state2))
								eventsToUpdate.add(neighbor.activeEvents.get(dependencyDestState));
					}
				}
			}

			public T getEndState()
			{
				return transition.getEndState();
			}

			public RateFunction getRateFunction()
			{
				return transition.getRateFunction();
			}

			public T[] getReactants()
			{
				return transition.getReactants();
			}

			public T getStartState()
			{
				return transition.getStartState();
			}
		}
	}
	
	private void updateCounts(T state, int delta)
	{
		Integer oldCount = counts.get(state);
		int newCount;
		if(oldCount == null)
		{
			newCount = delta;
		}
		else
		{
			newCount = oldCount + delta;
		}
		counts.put(state, newCount);
		
		totalCount += delta;
	}
	
	public int getTotalCount()
	{
		return totalCount;
	}
	
	public int getCount(T state)
	{
		Integer count = counts.get(state);
		if(count == null) return 0;
		return count;
	}
}
