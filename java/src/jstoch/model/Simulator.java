package jstoch.model;

import jstoch.logging.*;

public interface Simulator
{
	public double getTime();
	public double performNextEvent() throws SimulationException;
	public double runUntil(double time) throws SimulationException;
	public double runFor(double timestep) throws SimulationException;
	public void finish() throws SimulationException;

	public void addLogger(Logger logger);
	public void addPeriodicLogger(PeriodicLogger logger);
	public void addEventLogger(EventLogger logger);
}
