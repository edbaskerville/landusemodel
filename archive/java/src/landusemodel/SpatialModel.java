package landusemodel;

import java.util.*;
import java.util.Map.Entry;

import jstoch.model.*;
import jstoch.random.*;
import jstoch.space.Lattice;
import jstoch.space.Lattice.BoundaryCondition;
import jstoch.space.Lattice.NeighborhoodType;
import jstoch.util.*;

import static java.lang.Math.*;

import cern.jet.random.*;
import cern.jet.random.engine.*;

public class SpatialModel extends SuperModel
{
	Lattice<Site> space;
	Normal betaDist;
	
	EnumMap<State, IntW> stateCounts;
	
	double lastLifetimeUpdate;
	EnumMap<State, DoubleW> totalLifetimes;
	
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
		
		// Maintains map from class of event to the actual event object
		// so different objects can be easily retrieved/invalidated/etc.
		public Map<Class<? extends Event>, Event> activeEvents;
		
		public Site(State state, int row, int col)
		{
			this.state = state;
			this.row = row;
			this.col = col;
			activeEvents = new HashMap<Class<? extends Event>, Event>();
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
				performStateChange(time, State.Populated, State.Degraded, eventsToRemove, eventsToUpdate);
			}
			
			public double getRate()
			{
				assert(state == State.Populated);
				double a = getNeighborCount(State.Agricultural) / 8.0;
				return 1.0 - a/(a + config.c);
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
				
				if(config.deltaF)
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
					
					double fq = pow(nF / 8.0, config.q);
					return 1.0 -  fq/(fq + config.m);
				}
				else return config.delta;
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
								switch(config.productivityFunction)
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
						agriculturalProductivity /= 8.0;
						double alpha = (1.0 - config.k) * agriculturalProductivity/(agriculturalProductivity + config.r);
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
				
				if(config.epsilonF)
				{
					double nF = getNeighborCount(State.Forest);
					return config.epsilon * nF / 8.0;
					
				}
				else
					return config.epsilon;
			}
		}
		
		
		/**
		 * Inner class representing global colonization events (D->P or F->P).
		 * Unlike other events, which are applied to the site that is changing state,
		 * this event is centered around the "colonizer," and then a random colonized site
		 * is chosen from those available.
		 */
		class GlobalDFPEvent extends SiteEvent
		{
			public void performEvent(double time, Set<Event> eventsToRemove,
					Set<Event> eventsToUpdate)
			{
				assert(state == State.Populated);
				
				int totalCount = stateCounts.get(State.Forest).value + stateCounts.get(State.Degraded).value;
				
				if(totalCount > 0)
				{
					Uniform unif = new Uniform(rng);
					
					Site site;
					do
					{
						int row = unif.nextIntFromTo(0, config.L-1);
						int col = unif.nextIntFromTo(0, config.L-1);
						site = space.get(row, col);
					} while(site.state != State.Forest && site.state != State.Degraded);
					
					site.performStateChange(time, site.state, State.Populated, eventsToRemove, eventsToUpdate);
					site.beta = beta;
				}
			}
			
			public double getRate()
			{
				assert(state == State.Populated);
				double agriculturalProductivity = 0;
				for(Site siteA : space.getNeighbors(row, col))
				{
					if(siteA.state == State.Agricultural)
					{
						switch(config.productivityFunction)
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
				return config.k * agriculturalProductivity/(agriculturalProductivity + config.r);
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
				//else if(beta > 1) beta = 1;
				
				for(Site site : getNeighbors())
				{
					if(site.state == State.Forest)
					{
						eventsToUpdate.add(site.getEvent(FAEvent.class));
					}
				}
			}
			
			public double getRate()
			{
				assert(state == State.Populated);
				return config.sigma;
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
			addEvent(new PDEvent());
			addEvent(new BetaChangeEvent());
			if(config.k > 0.0)
				addEvent(new GlobalDFPEvent());
		}

		void setUpEventsAgricultural()
		{
			addEvent(new ADEvent());
		}

		void setUpEventsForest()
		{
			addEvent(new FAEvent());
			if(config.k < 1.0)
				addEvent(new DFPEvent());
		}
		
		void setUpEventsDegraded()
		{
			addEvent(new DFEvent());
			
			if(config.useDP && config.k < 1.0)
				addEvent(new DFPEvent());
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
						events.add(site.getEvent(ADEvent.class));
						break;
					case Forest:
						events.add(site.getEvent(FAEvent.class));
						if(config.k < 1.0)
							events.add(site.getEvent(DFPEvent.class));
						break;
					case Degraded:
						if(config.useDP && config.k < 1.0)
							events.add(site.getEvent(DFPEvent.class));
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
					if(config.k > 0.0)
						events.add(site.getEvent(GlobalDFPEvent.class));
					
					events.add(site.getEvent(PDEvent.class));
					
					if(config.useDP && config.k < 1.0)
					{
						for(Site site2 : site.getNeighbors())
						{
							if(site2.state == State.Degraded || site2.state == State.Forest)
								events.add(site2.getEvent(DFPEvent.class));
						}
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
					events.add(site.getEvent(ADEvent.class));
					
					if(config.productivityFunction == Config.ProductivityFunction.AF)
					{
						for(Site site2 : site.getNeighbors())
							if(site2.state == State.Populated)
							{
								if(config.k > 0.0)
									events.add(site2.getEvent(GlobalDFPEvent.class));
								
								if(config.useDP && config.k < 1.0)
								{
									for(Site site3 : site2.getNeighbors())
										if(site3.state == State.Degraded || site3.state == State.Forest)
											events.add(site3.getEvent(DFPEvent.class));
								}
							}
					}
				}
				else if(config.epsilonF && site.state == State.Degraded)
				{
					events.add(site.getEvent(DFEvent.class));
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
		void addEvent(Event event)
		{
			activeEvents.put(event.getClass(), event);
		}
		
		/**
		 * Convenience method (for readability) to retrieve an event object.
		 * @param cl The class of the event.
		 * @return The event object.
		 */
		Event getEvent(Class<? extends Event> cl)
		{
			return activeEvents.get(cl);
			/*Event event = activeEvents.get(cl);
			if(event == null)
			{
				System.err.println("null event!");
			}
			
			return event;*/
		}
	}
	
	/**
	 * Constructor. Simply records the rng: other initialization happens in initialize().
	 * @param rng
	 */
	public SpatialModel(RandomEngine rng, Config config)
	{
		super(rng, config);
	}
	
	/**
	 * Initializes the model when asked by the simulator. Initialization
	 * is deferred so that parameters can be changed after object creation
	 * but before a simulation run, roughly akin to "object phases" in Swarm.
	 */
	public void initialize()
	{
		betaDist = new Normal(0, 0.01, rng);
		space = new Lattice<Site>(config.L, config.L, BoundaryCondition.Periodic, NeighborhoodType.Moore);
		int initPopLoc = config.L/2;
		
		for(int row = 0; row < config.L; row++)
		{
			for(int col = 0; col < config.L; col++)
			{
				Site site;
				if(row == initPopLoc && col == initPopLoc)
				{
					site = new Site(State.Populated, row, col);
					site.beta = config.beta0;
				}
				else
				{
					site = new Site(State.Forest, row, col);
				}
				site.setUpEvents();
				space.put(site, row, col);
			}
		}
		
		lastLifetimeUpdate = 0;
		totalLifetimes = new EnumMap<State, DoubleW>(State.class);
		totalLifetimes.put(State.Populated, new DoubleW(0));
		totalLifetimes.put(State.Agricultural, new DoubleW(0));
		totalLifetimes.put(State.Forest, new DoubleW(0));
		totalLifetimes.put(State.Degraded, new DoubleW(0));
		
		stateCounts = new EnumMap<State, IntW>(State.class);
		stateCounts.put(State.Populated, new IntW(1));
		stateCounts.put(State.Agricultural, new IntW(0));
		stateCounts.put(State.Forest, new IntW(config.L*config.L - 1));
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
	
	@Override
	void updateLifetimes(double time)
	{
		// Update lifetimes
		for(Entry<State, DoubleW> entry : totalLifetimes.entrySet())
		{
			entry.getValue().value += stateCounts.get(entry.getKey()).value * (time - lastLifetimeUpdate);
		}
		
		lastLifetimeUpdate = time;
	}
	
	@Override
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
		
		for(int row = 0; row < config.L; row++)
		{
			for(int col = 0; col < config.L; col++)
			{
				Site site = space.get(row, col);
				events.addAll(site.activeEvents.values());
			}
		}
		
		return events;
	}

	@Override
	double[] getSortedBetas() {
		double betas[] = new double[getCount(State.Populated)];

		int i = 0;
		for(int row = 0; row < config.L; row++) {
			for (int col = 0; col < config.L; col++) {
				SpatialModel.Site site = space.get(row, col);
				if(site.state == State.Populated) {
					betas[i] = site.beta;
					i++;
				}
			}
		}

		Arrays.sort(betas);
		return betas;
	}
}
