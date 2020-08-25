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


### Colonization events (`F -> H` or `D -> H`)

A site in state `H` may colonize another site in state `D` or state `F`.

The new site `j` is assigned `beta_j = beta_i`.

The colonization event may be local or global, and the ratio of local vs. global events is controlled by parameter `k`.

#### Global colonization

The rate (probability per unit time) of site `i` colonizing a randomly chosen site on the lattice in state `D` or state `F` is equal to

```
alpha_i = k * a_i / (a_i + r)
```

where `a_i` is the "agricultural productivity" of site `i`.


#### Local colonization

The rate of site `i` colonizing a neighbor `j` is equal to

```
alpha_ij = (1 - k) * a_i / (a_i + r)
```


#### Agricultural productivity function

Two forms are allowed for the agricultural productivity `a_i`.

The first form only depends on the fraction of neighboring sites that are agricultural:

```
a_i(A) = n_A(i) / 8
```

where `n_A(i)` is the number of neighbors of site `i` that are in state `A`.

The second form is related not only to the number of agricultural neighbors, but also to the fraction of *their* neighbors that are in state `F`:

```
a_i(AF) = [ sum_{j | S_j = A} f_j ] / 8
```

where `f_j = n_F(j) / 7`, since 7 is the maximum number of neighbors that could be forested.


### Degradation events (`A -> D`)

If configuration parameter `deltaF` is `true`, then sites in state `A` are converted to state `D` at the rate `delta`.

If `deltaF` is `false`, then a site `i` in state `A` is converted to state `D` at rate

```
1.0 - fq / (fq + m)
```

where

```
fq = (n_F(i) / 8)^q
```

if it has any populated neighbors.

Otherwise, it is converted to state `D` at rate `1.0`.

NOTE: we have been using `deltaF = true`. Is that what we want?


### Abandonment events (`H -> D`)

Sites in state `H` are converted to state `D` at rate

```
1 - [a / (a + c)]
```

where `a` is the fraction of neighbors in state `A`.


### Conversion to agriculture (`F -> A`)

A site in state `H` converts neighbors in state `F` to state `A` at rate `beta`.


### Recovery of degraded land (`D -> F`)

If configuration parameter `epsilonF` is `true`, then degraded land recovers to state `F` at rate

```
epsilon * n_F(i) / 8
```

Otherwise, degraded land recovers to state `F` at rate `epsilon`.

NOTE: we have been using `epsilonF = false`. Is that what we want?

### `beta` evolution events

The rate `beta` at which a populated site converts forested neighbors into agricultural land randomly evolves according to parameter `sigma`.

At rate `sigma`, the value `beta_i` is set to a new value drawn from

```
beta_i[t + dt] = Normal(beta_i[t], 0.01)
```

NOTE: better to use `sigma` for the standard deviation of the random walk, not for the rate at which random walk events occur!

NOTE 2: probably better to hard-code the rate rather than hard-coding the standard deviation! (Best to hard-code neither.)


## Parameter summary

TODO.

All rates are in the same time units as the output.
E.g., if these time units are interpreted as being days, then a rate of 1 means that on average an event happens once per day.
