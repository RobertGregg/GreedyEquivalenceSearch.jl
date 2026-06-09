library(rCausalMGM)
library(stringr)


###################
#Small Dataset
###################
sim <- simRandomDAG(n=10000, p=250, discFrac=0.0, deg=4, coefMin=0.5,
                    coefMax=1.5, noiseMin=1, noiseMax=2, seed=1)

write.csv(sim$data,file = "simulatedDAGs/large_sim_data.csv", row.names=FALSE)


write.csv(sim$graph$edges,
          file = "simulatedDAGs/large_sim_graph.csv",
          col.names = FALSE,
          row.names=FALSE)





# =============================================================================
# Simulate Many Random DAGs with Varying Parameters
# =============================================================================
# discFrac is fixed at 0.0 throughout. All other arguments can be varied.
# Outputs are saved to output_dir as:
#   dag_data_<id>.csv   — the generated dataset
#   dag_graph_<id>.csv  — the adjacency/edge list of the graph
#   dag_manifest.csv    — maps each id to its full parameter set
# =============================================================================

library(rCausalMGM)
library(stringr)

# --- 1. Output directory -----------------------------------------------------
output_dir <- "simulatedDAGs"
# dir.create(output_dir, showWarnings = FALSE)

# --- 2. Define the parameter grid --------------------------------------------
# Add or remove values in each vector to control what gets simulated.
# Every combination of the vectors below will be run.

param_grid <- expand.grid(
  n        = c(500, 1000),          # sample sizes
  p        = c(20, 50),             # number of features
  deg      = c(2, 3, 8),            # average graph degree
  coefMin  = c(0.5),                # lower bound on effect size
  coefMax  = c(1.5),                # upper bound on effect size
  noiseMin = c(1),                  # lower bound on noise SD
  noiseMax = c(2),                  # upper bound on noise SD
  seed     = 1:3,                   # replicate seeds per configuration
  discFrac = 0.0,                   # FIXED — do not change
  stringsAsFactors = FALSE
)

cat(sprintf("Total configurations to simulate: %d\n", nrow(param_grid)))

# --- 3. Simulation loop ------------------------------------------------------
manifest <- vector("list", nrow(param_grid))

for (i in seq_len(nrow(param_grid))) {
  p <- param_grid[i, ]
  
  cat(sprintf(
    "[%d/%d] n=%d p=%d deg=%d coefMin=%.1f coefMax=%.1f noiseMin=%.1f noiseMax=%.1f seed=%d\n",
    i, nrow(param_grid),
    p$n, p$p, p$deg, p$coefMin, p$coefMax, p$noiseMin, p$noiseMax, p$seed
  ))
  
  # --- Run the simulation ----------------------------------------------------
  result <- tryCatch(
    simRandomDAG(
      n        = p$n,
      p        = p$p,
      discFrac = 0.0,          # always zero
      deg      = p$deg,
      coefMin  = p$coefMin,
      coefMax  = p$coefMax,
      noiseMin = p$noiseMin,
      noiseMax = p$noiseMax,
      seed     = p$seed
    ),
    error = function(e) {
      warning(sprintf("Configuration %d failed: %s", i, e$message))
      NULL
    }
  )
  
  if (is.null(result)) next
  
  # --- Save dataset ----------------------------------------------------------
  # Adjust result$data / result$graph to match whatever simRandomDAG returns
  data_path  <- file.path(output_dir, sprintf("dag_data_%04d.csv",  i))
  graph_path <- file.path(output_dir, sprintf("dag_graph_%04d.csv", i))
  
  write.csv(result$data,  data_path,  row.names = FALSE)
  write.csv(result$graph$edges, graph_path, row.names = FALSE)
  
  # --- Record in manifest ----------------------------------------------------
  manifest[[i]] <- data.frame(
    id         = i,
    data_file  = basename(data_path),
    graph_file = basename(graph_path),
    n          = p$n,
    p          = p$p,
    discFrac   = 0.0,
    deg        = p$deg,
    coefMin    = p$coefMin,
    coefMax    = p$coefMax,
    noiseMin   = p$noiseMin,
    noiseMax   = p$noiseMax,
    seed       = p$seed,
    stringsAsFactors = FALSE
  )
}

# --- 4. Write manifest -------------------------------------------------------
manifest_df <- do.call(rbind, manifest)
write.csv(manifest_df, file.path(output_dir, "dag_manifest.csv"), row.names = FALSE)

cat(sprintf(
  "\nDone. %d DAGs saved to '%s/'. Manifest: dag_manifest.csv\n",
  nrow(manifest_df), output_dir
))