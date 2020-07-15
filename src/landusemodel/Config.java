package landusemodel;

public class Config {
	boolean spatial = true;
	Integer randomSeed = null;
	
	double globalFraction = 0.0;
	double maxTime = 10000;

	boolean outputStateChanges = false;
	boolean outputImages = false;
	boolean outputFullState = false;

	// Full state output interval
	double stateChangeInterval = 1.0;
	
	// Image output interval
	double imageInterval = 1.0;

	// Full state output interval
	double fullStateInterval = 1.0;
	
	// Logging interval
	double logInterval = 1.0;
	
	Integer runNum = null;
	
	// Beta evolution rate
	double mu = 0.2;
	
	// Parameter controlling P->D rate
	double c = 0.01;
	
	// If deltaF == true, the A->D rate depends on the fraction
	// of forested neighbors.
	boolean deltaF = true;
	
	// Parameter controlling constant A->D rate
	double delta = 0.5;
	
	// Settings controlling variable A->D rate
	double m = 0.3;
	double q = 1;
	
	// Parameter controlling D->F rate
	double eps = 0.3;
	
	// If epsF == true, the D->F rate depends on the fraction
	// of forested neighbors.
	boolean epsF = false;
	
	// F->A rate of initial individual
	double beta0 = 1.0;
	
	// Parameter controlling F->P, D->P rate
	double r = 12;
	
	// If useDP == true, degraded sites can be invaded by populated sites;
	// if useDP == false, they cannot
	boolean useDP = false;
	
	// Parameter controlling dependence on D->P/F->P rate
	// "A" just depends on agricultural sites;
	// "AF depends on the productivity of the agricultural sites
	// taking into account the presence of forest around them
	enum ProductivityFunction
	{
		A,
		AF
	}
	
	ProductivityFunction productivityFunction = ProductivityFunction.A;
	
	// Size of lattice
	int L = 20;
}
