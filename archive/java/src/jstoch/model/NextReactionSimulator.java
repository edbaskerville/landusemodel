package jstoch.model;

import jstoch.logging.*;
import cern.jet.random.engine.RandomEngine;

public class NextReactionSimulator implements Simulator
{
	public NextReactionSimulator(StochasticModel model, RandomEngine rng)
	{
	}
	
	public void addEventLogger(EventLogger logger)
	{
		// TODO Auto-generated method stub
	}
	
	public void addLogger(Logger logger)
	{
		// TODO Auto-generated method stub	
	}
	
	public void addPeriodicLogger(PeriodicLogger logger)
	{
		// TODO Auto-generated method stub
	}
	
	public void finish() throws SimulationException
	{
		// TODO Auto-generated method stub
	}
	
	public double getTime()
	{
		// TODO Auto-generated method stub
		return 0;
	}
	
	public double performNextEvent() throws SimulationException
	{
		// TODO Auto-generated method stub
		return 0;
	}
	
	public double runFor(double timestep) throws SimulationException
	{
		// TODO Auto-generated method stub
		return 0;
	}
	
	public double runUntil(double time) throws SimulationException
	{
		// TODO Auto-generated method stub
		return 0;
	}

// BELOW HERE IS NEXT-REACTION IMPLEMENTATION FROM OLDER VERSION OF SOFTWARE.
// FOR REFERENCE IN IMPLEMENTING NEW VERSION ONLY.

//	public NextReactionSimulator(StochasticModel model, Parameters params)
//	{
//		this.model = model;
//		
//		this.populations = model.getPopulations();
//		
//		timeDist = new Exponential(1, model.getRandomEngine());
//		time = 0;
//		
//		List<Reaction> reactionList = model.getReactionList();
//		reactionDependencies = getReactionDependencies(reactionList);
//		initializeReactionQueue(reactionList);
//	}
//	
//	void initializeReactionQueue(List<Reaction> reactionList)
//	{
//		reactionQueue = new IndexedPriorityQueue<ReactionState>();
//		stateMap = new HashMap<Reaction, ReactionState>();
//		
//		for(Reaction rxn : reactionList)
//		{
//			ReactionState state = new ReactionState(rxn);
//			stateMap.put(rxn, state);
//			
//			state.rate = rxn.getRate(populations);
//			
//			if(state.rate != 0)
//			{
//				state.time = timeDist.nextDouble(state.rate);
//			}
//			else
//			{
//				state.time = Double.POSITIVE_INFINITY;
//			}
//			reactionQueue.add(state);
//		}
//		reactionQueue.buildHeap();
//	}
//	
//	public double nextReaction()
//			throws SimulationException
//	{
//		
//		ReactionState state = reactionQueue.head();
//		
//		time = state != null ? state.time : Double.POSITIVE_INFINITY;
//		try
//		{
//			model.logPeriodic(time);
//		}
//		catch(LoggingException e)
//		{
//			throw new SimulationException("Logging exception thrown", e);
//		}
//		
//		if(time != Double.POSITIVE_INFINITY)
//		{
//			performReaction(state.reaction);
//			try
//			{
//				model.logEvent(time, state.reaction);
//			}
//			catch(LoggingException e)
//			{
//				throw new SimulationException("Logging exception thrown", e);
//			}
//		}
//		return time;
//	}
//	
//	private void performReaction(Reaction rxn) throws SimulationException
//	{
//		boolean shouldPerformReaction = true;
//		if(rxn.checkReaction)
//		{
//			for(StateChange stateChange : rxn.stateChanges)
//			{
//				if(!canDoStateChange(stateChange, populations))
//				{
//					shouldPerformReaction = false;
//					break;
//				}
//			}
//		}
//		
//		if(shouldPerformReaction)
//		{
//			Set<Species> affectedSpecies = new HashSet<Species>();
//			for(StateChange stateChange : rxn.stateChanges)
//			{
//				doStateChange(time, stateChange, populations);
//				affectedSpecies.add(stateChange.getSpecies());
//			}
//			recalculateDependentReactions(rxn, affectedSpecies);
//		}
//	}
//	
//	private void recalculateDependentReactions(Reaction sourceRxn, Set<Species> speciesSet)
//	{
//		Set<Reaction> affectedRxns = reactionDependencies.get(sourceRxn);
//		
//		for(Reaction rxn : affectedRxns)
//		{
//			ReactionState state = stateMap.get(rxn);
//			double newRate = rxn.getRate(populations);
//			double newTime;
//			
//			if(newRate == 0)
//			{
//				state.rate = 0;
//				state.time = Double.POSITIVE_INFINITY;
//			}
//			else
//			{
//				if(rxn == sourceRxn || state.rate == 0)
//				{
//					newTime = time + timeDist.nextDouble(newRate);
//				}
//				else
//				{
//					newTime = time + (state.time - time) * state.rate / newRate;
//				}
//				state.rate = newRate;
//				state.time = newTime;
//			}
//			reactionQueue.update(state);
//		}
//	}
//	
//	public boolean verify(int numDraws)
//	{
//		return false;
//	}
//	
//	public double getTime()
//	{
//		return time;
//	}
//	
//	private class ReactionState implements Comparable<ReactionState>
//	{
//		public Reaction reaction;
//		public double rate;
//		public double time;
//		
//		public ReactionState(Reaction reaction)
//		{
//			super();
//			this.reaction = reaction;
//		}
//		
//		public int compareTo(ReactionState obj)
//		{
//			double otherTime = obj.time;
//			if(time < otherTime) return -1;
//			if(time > otherTime) return 1;
//			return 0;
//		}
//	}
//	
//	private StochasticModel model;
//	private double time;
//	
//	private int[] populations;
//	private Map<Reaction, Set<Reaction>> reactionDependencies;
//	
//	private IndexedPriorityQueue<ReactionState> reactionQueue;
//	private Map<Reaction, ReactionState> stateMap;
//	
//	private Exponential timeDist;
}
