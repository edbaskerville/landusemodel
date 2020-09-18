# landusemodel

Implementation of a model of land-use change affected by perception of value. Model concept by Andres Baeza; implementation by Ed Baskerville.

## Summary of model

The model consists of an `L` x `L` square lattice of sites evolving stochastically in continuous time via discrete events.

Each site has eight neighbors (the Moore neighborhood).

Neighborhoods are governed by periodic (toroidal) boundary conditions, so that all sites have exactly eight neighbors.

Each site may be in one of four states:

* `H`: populated by humans
* `A`: agricultural
* `F`: forest
* `D`: degraded land

Sites can transition between these states according to the following transitions:

* Colonization: `F -> H` or `D -> H`
* Degradation of agricultural area: `A -> D`
* Abandonment of populated area: `H -> D`
* Conversion to agriculture: `F -> A`
* Recovery of degraded land: `D -> F`

Additionally, each populated site `i` (in state `H`) is associated with a positive-valued number `beta_i` representing the [ TODO ].
Values of `beta_i` also evolve due to discrete random jumps in continuous time.


### Colonization events (`F -> H`)

A site `i` in state `F` may transition to state `H` if it has neighbors in state `H`.

The new site `j` is assigned `beta_j = beta_k` for a neighbor `k` in state `H` chosen uniformly randomly.

The colonization event may be local—where neighbors include only the local Moore neighborhood—or global (well-mixed)—where neighbors include all human-occupied sites.
The ratio of local vs. global events is controlled by parameter `frac_global_FH`.

#### Global colonization

The rate of a site `i` in state `F` being colonized by an inhabited site anywhere on the lattice is equal to

```
frac_global_FH * global_frac_H * max_rate_FH * global_mean_probability_FH
```

where `frac_H_global == n_H / (L * L - 1)` is the global fraction of inhabited sites.
The function `global_mean_probability_FH` is the mean across all sites `j` in site `H` of a function `probability_FH(j)` that depends on the states of neighbors of `j` (see `Colonization rate probability functions` below).


#### Local colonization

The rate of a site `i` in state `F` being colonized by an inhabited site in the local Moore neighborhood is equal to

```
(1.0 - frac_global_FH) * frac_H(i) * max_rate_FH * mean_probability_FH(i)
```

where `frac_H(i)` is the fraction of neighbors of `i` in state `H`, and `mean_probability_FH(i)` is the mean, across neighbors of `i` in state `H`, of `probability_FH(j)`.


### Colonization rate probability functions

The function `probability_FH()` determines the fraction of a maximum rate `max_rate_FH` at which a site in state `H` colonizes its neighbors in state `F`.
The name `probability` is due to the fact that events occur via this procedure:

1. Choose a random site `i` in state `F`
2. Choose a random site `j` in state `H` (globally or from the local neighborhood)
3. Transition site `F` to site `H` with probability equal to `probability_FH(j)`.

This function takes one of two forms, depending on the simulation parameter `probability_function_FH`, which may be either `FH_A` or `FH_AF`.

If `probability_function_FH == FH_A`, we have `probability_FH(j) == probability_FH_A(j) == frac_A(j)`, the fraction of neighbors of site `j` in state `A`.

If `probability_function_FH = FH_AF`, we have `probability_FH(j) == probability_FH_AF(j)`, which is the mean, across neighbors `k` of `j`, of

```
frac_F(k)   for k in state A
0.0         otherwise
```

where `frac_F(k)` is the fraction of neighbors `l ≠ j` of `k` in state `F`.


### Degradation events (`A -> D`)

A site `i` in state `A` degrades to state `D` at a rate dependent on the number of neighbors in state `F`:

```
max_rate_AD * [min_rate_frac_AD + (1.0 - min_rate_frac_AD) * (1.0 - frac_F(i))]
```

That is, the rate goes from a minimum of `min_rate_frac_AD * max_rate_AD` when `i` has all neighbors in state `F`, up to a maximum of `max_rate_AD` when `i` has no neighbors in state `F`.


### Abandonment events (`H -> D`)

A site `i` in state `H` is converted to state `D` at rate

```
max_rate_AD * [min_rate_frac_HD + (1.0 - min_rate_frac_HD) * (1.0 - frac_A(i))]
```

where `frac_A` is the fraction of neighbors in state `A`.

That is, the rate goes from a minimum of `min_rate_frac_HD * max_rate_HD` when `i` has all neighbors in state `A`, up to a maximum of `max_rate_HD` when `i` has no neighbors in state `A`.


### Conversion to agriculture (`F -> A`)

A site `i` in state `F` is converted to state `A` at rate equal to

```
mean_beta_or_zero(i)
```

where `mean_beta_or_zero(i)` is the mean across all neighbors `j` of

```
beta(j)   for j in state H
0.0       otherwise
```


### Recovery of degraded land (`D -> F`)

Sites in state `D` recover to state `F` at rate `rate_DF`.


### `beta` evolution events

The value `beta` associated with a site in state `H` follows a random walk in log-space.
The standard deviation of the random walk on `log(beta)` after a time increment of 1 is equal to `sd_log_beta`.

Changes are applied to sites in state `H` at rate `rate_beta_change`.
This rate does not affect the expected amount of change in a unit of time; it only affects the number of discrete jumps that happen to create that change.

That is: at rate `rate_beta_change`, `beta` is updated as

```
beta *= beta * exp(v * sqrt(sd_log_beta^2 / rate_beta_change))
```

where `v` is a standard normal random variate.

