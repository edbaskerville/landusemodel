package jstoch.examples.sirmodel;

import jstoch.model.*;

public class Model extends DiscreteStateModel<State>
{
	double beta = 10.0;
	
	double nu = 1.0;
	
	int size = 1000;
	
	int latticeSize = 1000;
	
	public Model()
	{
		super(State.class);
		addTransition(State.Susceptible, State.Infected, // Start and end states
			new State[] { State.Infected }, // List of "reactants"
			new RateFunction()
			{
				public double getRate(int total, int... reactantPopulations)
				{
					return beta * reactantPopulations[0] / (double)total;
				}
			});
		
		addTransition(State.Infected, State.Recovered, null,
			new RateFunction()
			{
				public double getRate(int total, int... reactantPopulations)
				{
					return nu;
				}
			});
	}
}
