package jstoch.logging;

public class LoggingException extends Exception
{
	private static final long serialVersionUID = 1L;
	
	private Object logger;
	
	public LoggingException(PeriodicLogger logger)
	{
		super();
		this.logger = logger;
	}

	public LoggingException(PeriodicLogger logger, String message, Throwable cause)
	{
		super(message, cause);
		this.logger = logger;
	}

	public LoggingException(PeriodicLogger logger, String message)
	{
		super(message);
		this.logger = logger;
	}

	public LoggingException(PeriodicLogger logger, Throwable cause)
	{
		super(cause);
		this.logger = logger;
	}
	
	public LoggingException(EventLogger logger)
	{
		super();
		this.logger = logger;
	}

	public LoggingException(EventLogger logger, String message, Throwable cause)
	{
		super(message, cause);
		this.logger = logger;
	}

	public LoggingException(EventLogger logger, String message)
	{
		super(message);
		this.logger = logger;
	}

	public LoggingException(EventLogger logger, Throwable cause)
	{
		super(cause);
		this.logger = logger;
	}
	
	public Object getLogger()
	{
		return logger;
	}
}
