package jstoch.model;

@SuppressWarnings("serial")
public class SimulationException extends Exception
{
	public SimulationException()
	{
		super();
	}

	public SimulationException(String message, Throwable cause)
	{
		super(message, cause);
	}

	public SimulationException(String message)
	{
		super(message);
	}

	public SimulationException(Throwable cause)
	{
		super(cause);
	}
	
}
