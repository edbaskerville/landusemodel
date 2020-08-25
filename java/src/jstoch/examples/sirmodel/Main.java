package jstoch.examples.sirmodel;

import java.util.*;

import jstoch.model.*;
import jstoch.space.Lattice;
import jstoch.util.EasyMap;

import cern.jet.random.engine.*;

public class Main
{
	public static void main(String[] args) throws SimulationException
	{
		Main runner = new Main();
		runner.run();
	}
	
	private Double maxTime = 100.0;
	private boolean useLattice = false;
	private int size = 1000;
	private double textTimeStep = 0.1;
	private double imageTimeStep = 10.0;
	
	private Model model;
	
	public Main()
	{
		model = new Model();
		
		if(useLattice)
		{
			Lattice<State> space = new Lattice<State>(size, size,
					Lattice.BoundaryCondition.Periodic,
					Lattice.NeighborhoodType.VonNeumann);
			
			for(int row = 0; row < size; row++)
				for(int col = 0; col < size; col++)
					space.put(State.Susceptible, row, col);
			space.put(State.Infected, 0, 0);
			
			model.setSpace(space);
		}
		else
		{
			model.setInitialCounts(new EasyMap<State, Integer>(
					State.Susceptible, size * size - 1,
					State.Infected, 1,
					State.Recovered, 0));
		}
	}
	
	public void run() throws SimulationException
	{
		RandomEngine rng = new MersenneTwister(new Date());
		Simulator simulator = new GillespieDirectSimulator(model, rng);
		simulator.addPeriodicLogger(new TextLogger(textTimeStep));
		
		if(useLattice)
		{
			simulator.addLogger(new ImageLogger(imageTimeStep));
		}
		
		if(maxTime != null)
			simulator.runUntil(Double.POSITIVE_INFINITY);
		else
			simulator.runUntil(maxTime);
		
		simulator.finish();
	}
}
