package conservation;

import java.util.*;
import java.util.Map.Entry;

import jstoch.model.*;
import jstoch.parameters.*;
import jstoch.random.*;
import jstoch.space.Lattice;
import jstoch.space.Lattice.BoundaryCondition;
import jstoch.space.Lattice.NeighborhoodType;
import jstoch.util.*;

import static java.lang.Math.*;

import cern.jet.random.*;
import cern.jet.random.engine.*;

// TODO: implement non-spatial version

public class Model implements StochasticModel
{
	@Parameter(shortName="T")
	double maxTime = 10000;
	
	@Parameter(shortName="oi")
	boolean outputImages = false;
	
	// Image output interval
	@Parameter(shortName="ii")
	double imageInterval = 1000.0;
	
	// Logging interval
	@Parameter(shortName="li")
	double logInterval = 1.0;
	
	@Parameter(shortName="rn") Integer runNum = null;
	
	@Parameter(shortName="rs")
	Integer randomSeed = null;
	
	// Beta evolution rate
	@Parameter double mu = 0.2;
	
	// Parameter controlling P->D rate
	@Parameter double c = 0.01;
	
	// If deltaF == true, the A->D rate depends on the fraction
	// of forested neighbors.
	@Parameter boolean deltaF = true;
	
	// Parameter controlling constant A->D rate
	@Parameter double delta = 0.5;
	
	// Parameters controlling variable A->D rate
	@Parameter double m = 0.3;
	@Parameter double q = 1;
	
	// Parameter controlling D->F rate
	@Parameter double eps = 0.3;
	
	// If epsF == true, the D->F rate depends on the fraction
	// of forested neighbors.
	@Parameter boolean epsF = false;
	
	// F->A rate of initial individual
	@Parameter double beta0 = 1.0;
	
	// Parameter controlling F->P, D->P rate
	@Parameter double r = 12;
	
	// If useDP == true, degraded sites can be invaded by populated sites;
	// if useDP == false, they cannot
	@Parameter boolean useDP = true; 
	
	// Parameter controlling dependence on D->P/F->P rate
	// "A" just depends on agricultural sites;
	// "AF depends on the productivity of the agricultural sites
	// taking into account the presence of forest around them
	enum ProductivityFunction
	{
		A,
		AF
	}
	@Parameter(shortName="pf")
	ProductivityFunction productivityFunction = ProductivityFunction.A;
	
	// Size of lattice
	@Parameter int L = 100;

	RandomEngine rng;
	Lattice<Site> space;
	Normal betaDist;
	
	double betaSum;
	
	EnumMap<State, IntW> stateCounts;
	
	double lastLifetimeUpdate;
	EnumMap<State, DoubleW> totalLifetimes;
	
	/**
	 * Enumeration defining the four possible states of sites on the lattice:
	 * Populated, Agricultural, Forest, and Degraded.
	 */
	enum State
	{
		Populated(0xFF999999),
		Agricultural(0xFF804000),
		Forest(0xFF408000),
		Degraded(0xFF800000);
		
		int color;
		
		State(int color)
		{
			this.color = color;
		}
		
		public int color()
		{
			return color;
		}
	}
	
	/**
	 * Implements behavior for sites on the LxL lattice.
	 */
	class Site
	{
		State state;
		double beta;
		int row;
		int col;
		double birthTime;
		
		// Maintains map from destination state to associated event
		// E.g., if state == Populated, then
		// the map will contain two items, from Degraded to a PDEvent object,
		// and from Populated to a BetaChangeEvent object (for convenience).
		public EnumMap<State, Event> activeEvents;
		
		public Site(State state, int row, int col)
		{
			this.state = state;
			this.row = row;
			this.col = col;
			activeEvents = new EnumMap<State, Event>(State.class);
			birthTime = 0;
		}
		
		
		/*** EVENT CLASSES ***/ 
		
		/**
		 * Abstract event superclass to return the location and destination state of an event. 
		 */
		abstract class SiteEvent implements Event
		{
			public int getRow() { return row; }
			public int getCol() { return col; }
		}
		
		/**
		 * Inner class representing Populated->Degraded events (abandonment of populated area).
		 */
		class PDEvent extends SiteEvent
		{
			public void performEvent(double time, Set<Event> eventsToRemove,
					Set<Event> eventsToUpdate)
			{
				performStateChange(time ,State.Populated, State.Degraded, eventsToRemove, eventsToUpdate);
				betaSum -= beta;
			}
			
			public double getRate()
			{
				assert(state == State.Populated);
				double nA = getNeighborCount(State.Agricultural);
				return 1.0 - nA/(nA + c);
			}
		}

		/**
		 * Inner class representing Agricultural->Degraded events (abandonment of agricultural area).
		 */
		class ADEvent extends SiteEvent
		{
			public void performEvent(double time, Set<Event> eventsToRemove,
					Set<Event> eventsToUpdate)
			{
				performStateChange(time, State.Agricultural, State.Degraded, eventsToRemove, eventsToUpdate);
			}
			
			public double getRate()
			{
				assert(state == State.Agricultural);
				
				if(deltaF)
				{
					int nP = 0;
					int nF = 0;
					
					for(Site site : getNeighbors())
					{
						switch(site.state)
						{
							case Populated:
								nP++;
								break;
							case Forest:
								nF++;
								break;
						}
					}
					
					if(nP == 0) return 1.0;
					
					double nFq = pow(nF, q);
					return 1.0 -  nFq/(nFq + m);
				}
				else return delta;
			}
		}

		/**
		 * Inner class representing Forest->Agricultural events (conversion to productive land).
		 */
		class FAEvent extends SiteEvent
		{
			public void performEvent(double time, Set<Event> eventsToRemove,
					Set<Event> eventsToUpdate)
			{
				performStateChange(time, State.Forest, State.Agricultural, eventsToRemove, eventsToUpdate);
			}
			
			public double getRate()
			{
				assert(state == State.Forest);
				double betaTotal = 0;
				for(Site site : getNeighbors())
				{
					if(site.state == State.Populated)
					{
						betaTotal += site.beta; 
					}
				}
				return betaTotal;
			}
		}

		/**
		 * Inner class representing Degraded->Populated or Forest->Populated events (colonization).
		 */
		class DFPEvent extends SiteEvent
		{
			DiscreteDistributionBinaryTree<Site> populatedNeighbors;
			
			public void performEvent(double time, Set<Event> eventsToRemove,
					Set<Event> eventsToUpdate)
			{
				assert(state == State.Degraded || state == State.Forest);
				performStateChange(time, state, State.Populated, eventsToRemove, eventsToUpdate);
				
				beta = populatedNeighbors.nextValue().beta;
				betaSum += beta;
				populatedNeighbors = null;
			}
			
			public double getRate()
			{
				assert(state == State.Degraded || state == State.Forest);
				double alphaTotal = 0;
				HashMap<Site, Double> alphas = new HashMap<Site, Double>();
				for(Site siteP : space.getNeighbors(row, col))
				{
					if(siteP.state == State.Populated)
					{
						double agriculturalProductivity = 0;
						for(Site siteA : space.getNeighbors(siteP.row, siteP.col))
						{
							if(siteA.state == State.Agricultural)
							{
								switch(productivityFunction)
								{
									case A:
										agriculturalProductivity += 1.0;
										break;
									case AF:
										agriculturalProductivity += siteA.getNeighborCount(State.Forest) / 7.0;
										break;
								}
							}
						}
						double alpha = agriculturalProductivity/(agriculturalProductivity + r);
						alphas.put(siteP, alpha);
						alphaTotal += alpha;
					}
				}
				if(alphas.size() > 0)
					populatedNeighbors = new DiscreteDistributionBinaryTree<Site>(alphas, rng);
				return alphaTotal;
			}
		}
		
		/**
		 * Inner class representing Degraded->Forest events (land recovery).
		 */
		class DFEvent extends SiteEvent
		{
			public void performEvent(double time, Set<Event> eventsToRemove,
					Set<Event> eventsToUpdate)
			{
				performStateChange(time, State.Degraded, State.Forest, eventsToRemove, eventsToUpdate);
			}
			
			public double getRate()
			{
				assert(state == State.Degraded);
				
				if(epsF)
				{
					double nF = getNeighborCount(State.Forest);
					return eps * nF / 8.0;
					
				}
				else
					return eps;
			}
		}
		
		/**
		 * Inner class representing change of beta (rate at which people convert land to agriculture).
		 */
		class BetaChangeEvent extends SiteEvent
		{
			public void performEvent(double time, Set<Event> eventsToRemove,
					Set<Event> eventsToUpdate)
			{
				assert(state == State.Populated);
				double oldBeta = beta;
				beta += betaDist.nextDouble();
				if(beta < 0) beta = 0;
				else if(beta > 1) beta = 1;
				betaSum += beta - oldBeta;
				
				for(Site site : getNeighbors())
				{
					if(site.state == State.Forest)
					{
						eventsToUpdate.add(site.getTransitionEvent(State.Agricultural));
					}
				}
			}
			
			public double getRate()
			{
				assert(state == State.Populated);
				return mu;
			}
		}
		
		/**
		 * Performs a change in state, including 
		 * @param from The previous state. Included only for verification.
		 * @param to The destination state.
		 * @param eventsToRemove Set object to add old events to for removal from simulation engine.
		 * @param eventsToUpdate Set object to add new/updated events to for use by simulation engine.
		 */
		void performStateChange(double time, State from, State to, Set<Event> eventsToRemove, Set<Event> eventsToUpdate)
		{
			assert(state == from);
			state = to;
			
			updateLifetimes(time);
			
			stateCounts.get(from).value--;
			stateCounts.get(to).value++;
			
			totalLifetimes.get(from).value -= (time - birthTime);
			birthTime = time;
			
			// Remove existing events at this site
			eventsToRemove.addAll(activeEvents.values());
			activeEvents.clear();
			
			// Add events associated with new state
			setUpEvents();
			eventsToUpdate.addAll(activeEvents.values());
			
			// Update all events dependent on from and to states
			addDependencies(eventsToUpdate, from);
			addDependencies(eventsToUpdate, to);
		}
		
		/**
		 * Sets up all the events from scratch. Used during initialization
		 * and state changes.
		 */
		void setUpEvents()
		{
			assert(activeEvents.size() == 0);
			switch(state)
			{
				case Populated:
					setUpEventsPopulated();
					break;
				case Agricultural:
					setUpEventsAgricultural();
					break;
				case Forest:
					setUpEventsForest();
					break;
				case Degraded:
					setUpEventsDegraded();
					break;
			}
		}
		
		void setUpEventsPopulated()
		{
			addEvent(State.Degraded, new PDEvent());
			addEvent(State.Populated, new BetaChangeEvent());
		}

		void setUpEventsAgricultural()
		{
			addEvent(State.Degraded, new ADEvent());
		}

		void setUpEventsForest()
		{
			addEvent(State.Agricultural, new FAEvent());
			addEvent(State.Populated, new DFPEvent());
		}
		
		void setUpEventsDegraded()
		{
			addEvent(State.Forest, new DFEvent());
			
			if(useDP)
				addEvent(State.Populated, new DFPEvent());
		}
		
		/**
		 * Adds the events dependent on this site being in a particular state.
		 * Events may belong to neighbors, or to neighbors' neighbors, or...
		 * @param events Set to add events to for updating by simulation engine.
		 * @param state The state for which dependent events will be found.
		 */
		void addDependencies(Set<Event> events, State state)
		{
			switch(state)
			{
				case Populated:
					addDependenciesPopulated(events);
					break;
				case Agricultural:
					addDependenciesAgricultural(events);
					break;
				case Forest:
					addDependenciesForest(events);
					break;
				case Degraded:
					// No neighbor transitions depend on # of degraded sites
					break;
			}
		}
		
		void addDependenciesPopulated(Set<Event> events)
		{
			for(Site site : getNeighbors())
			{
				switch(site.state)
				{
					case Agricultural:
						events.add(site.getTransitionEvent(State.Degraded));
						break;
					case Forest:
						events.add(site.getTransitionEvent(State.Agricultural));
						events.add(site.getTransitionEvent(State.Populated));
						break;
					case Degraded:
						if(useDP)
							events.add(site.getTransitionEvent(State.Populated));
						break;
				}
			}
		}

		void addDependenciesAgricultural(Set<Event> events)
		{
			for(Site site : getNeighbors())
			{
				if(site.state == State.Populated)
				{
					events.add(site.getTransitionEvent(State.Degraded));
					
					for(Site site2 : site.getNeighbors())
					{
						if(useDP && site2.state == State.Degraded || site2.state == State.Forest)
							events.add(site2.getTransitionEvent(State.Populated));
					}
				}
			}
		}

		void addDependenciesForest(Set<Event> events)
		{
			for(Site site : getNeighbors())
			{
				if(site.state == State.Agricultural)
				{
					events.add(site.getTransitionEvent(State.Degraded));
					
					if(productivityFunction == ProductivityFunction.AF)
					{
						for(Site site2 : site.getNeighbors())
							if(site2.state == State.Populated)
								for(Site site3 : site2.getNeighbors())
									if(useDP && site3.state == State.Degraded || site3.state == State.Forest)
										events.add(site3.getTransitionEvent(State.Populated));
					}
				}
				else if(epsF && site.state == State.Degraded)
				{
					events.add(site.getTransitionEvent(State.Forest));
				}
			}
		}
		
		/**
		 * Convenience method to return neighbors of this site.
		 * Simply calls getNeighbors() on the space object.
		 * @return The neighbors of this site.
		 */
		List<Site> getNeighbors()
		{
			return space.getNeighbors(row, col);
		}
		
		/**
		 * Convenience method to return the number of neighbors in a particular state.
		 * @param state The state to count.
		 * @return The number of neighbors in the state.
		 */
		int getNeighborCount(State state)
		{
			int count = 0;
			for(Site site : getNeighbors())
			{
				if(site.state == state) count++;
			}
			return count;
		}
		
		/**
		 * Convenience method  for readability) to add an event to
		 * the map of active events.
		 * @param to The destination state. (Start state is the current state.)
		 * @param event The event object.
		 */
		void addEvent(State to, Event event)
		{
			activeEvents.put(to, event);
		}
		
		/**
		 * Convenience method (for readability) to retrieve an event object.
		 * @param to The destination state. (Start state is the current state.)
		 * @return The event object.
		 */
		Event getTransitionEvent(State to)
		{
			return activeEvents.get(to);
		}
	}
	
	/**
	 * Constructor. Simply records the rng: other initialization happens in initialize().
	 * @param rng
	 */
	public Model(RandomEngine rng, int rs)
	{
		this.rng = rng;
		this.randomSeed = rs;
	}
	
	/**
	 * Initializes the model when asked by the simulator. Initialization
	 * is deferred so that parameters can be changed after object creation
	 * but before a simulation run, roughly akin to "object phases" in Swarm.
	 */
	public void initialize()
	{
		betaDist = new Normal(0, 0.01, rng);
		space = new Lattice<Site>(L, L, BoundaryCondition.Periodic, NeighborhoodType.Moore);
		int initPopLoc = L/2;
		
		for(int row = 0; row < L; row++)
		{
			for(int col = 0; col < L; col++)
			{
				Site site;
				if(row == initPopLoc && col == initPopLoc)
				{
					site = new Site(State.Populated, row, col);
					site.beta = beta0;
				}
				else
				{
					site = new Site(State.Forest, row, col);
				}
				site.setUpEvents();
				space.put(site, row, col);
			}
		}
		betaSum = beta0;
		
		lastLifetimeUpdate = 0;
		totalLifetimes = new EnumMap<State, DoubleW>(State.class);
		totalLifetimes.put(State.Populated, new DoubleW(0));
		totalLifetimes.put(State.Agricultural, new DoubleW(0));
		totalLifetimes.put(State.Forest, new DoubleW(0));
		totalLifetimes.put(State.Degraded, new DoubleW(0));
		
		stateCounts = new EnumMap<State, IntW>(State.class);
		stateCounts.put(State.Populated, new IntW(1));
		stateCounts.put(State.Agricultural, new IntW(0));
		stateCounts.put(State.Forest, new IntW(L*L - 1));
		stateCounts.put(State.Degraded, new IntW(0));
	}
	
	/**
	 * Returns number of sites in a given state.
	 * @param state The state to retrieve counts for.
	 * @return The number of sites in the state.
	 */
	public int getCount(State state)
	{
		return stateCounts.get(state).value;
	}
	
	/**
	 * Calculates the average value of beta across all populated sites.
	 * @return The average value of beta, or zero if there are no populated sites.
	 */
	public double getBetaMean()
	{
		int numPop = getCount(State.Populated);
		return numPop == 0 ? 0.0 : betaSum / numPop;
	}
	
	void updateLifetimes(double time)
	{
		// Update lifetimes
		for(Entry<State, DoubleW> entry : totalLifetimes.entrySet())
		{
			entry.getValue().value += stateCounts.get(entry.getKey()).value * (time - lastLifetimeUpdate);
		}
		
		lastLifetimeUpdate = time;
	}
	
	double getAvgLifetime(State state)
	{
		return totalLifetimes.get(state).value / stateCounts.get(state).value;
	}
	
	/**
	 * Enumerates all the events currently possible. In fact, some events
	 * may be impossible (have rate zero), but that is not known until the
	 * rate calculation actually takes place.
	 * This method is only called once, during initialization.
	 */
	public List<Event> getAllEvents()
	{
		ArrayList<Event> events = new ArrayList<Event>();
		
		for(int row = 0; row < L; row++)
		{
			for(int col = 0; col < L; col++)
			{
				Site site = space.get(row, col);
				events.addAll(site.activeEvents.values());
			}
		}
		
		return events;
	}
}
