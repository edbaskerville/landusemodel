# Colors for grid states
state_colors <- c(
  H = hcl(h = 25, c = 51, l = 60, fixup = F),
  A = hcl(h = 70, c = 45, l = 80, fixup = F),
  F = hcl(h = 115, c = 52, l = 40, fixup = F),
  D = hcl(h = 0, c = 0, l = 20, fixup = F)
)

# Colors for A vs. AF
variant_colors <- c(
  A = hcl(h = 70, c = 45, l = 80, fixup = F),
  AF = hcl(h = 115, c = 52, l = 40, fixup = F)
)

plot_state_colors <- function() {
  library(ggplot2)
  df <- data.frame(
    state = factor(
      c('H', 'A', 'F', 'D'), 
      levels = c('H', 'A', 'F', 'D')
    ),
    height = c(1.1, 0.9, 1.2, 0.8)
  )
  
  ggplot(df, aes(x = state, y = height, fill = state)) +
    geom_col() +
    scale_fill_manual(values = state_colors)
}

plot_variant_colors <- function() {
  library(ggplot2)
  df <- data.frame(
    variant = factor(
      c('A', 'AF'),
      levels = c('A', 'AF'),
    ),
    height = c(0.9, 1.1)
  )
  
  ggplot(df, aes(x = variant, y = height, fill = variant)) +
    geom_col() +
    scale_fill_manual(values = variant_colors)
}


