package landusemodel;

import cern.jet.random.engine.RandomEngine;
import jstoch.model.StochasticModel;

public abstract class SuperModel implements StochasticModel
{
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
	

	abstract double getBetaMean();
	abstract int getCount(State state);
	abstract double getAvgLifetime(State state);
	abstract void updateLifetimes(double time);
	
	protected RandomEngine rng;
	protected Config config;
	
	public SuperModel(RandomEngine rng, Config config) {
		this.rng = rng;
		this.config = config;
	}
}
