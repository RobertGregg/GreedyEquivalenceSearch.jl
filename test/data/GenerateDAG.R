library(rCausalMGM)


sim <- simRandomDAG(n=1000, p=50, discFrac=0.0, deg=3, coefMin=0.5,
                    coefMax=1.5, noiseMin=1, noiseMax=2, seed=1)

write.csv(sim$data,file = "rCausalMGM_sim_data.csv", row.names=FALSE)


write.csv(sim$graph$edges,
          file = "rCausalMGM_sim_graph.csv",
          col.names = FALSE,
          row.names=FALSE)





sim <- simRandomDAG(n=1000, p=500, discFrac=0.0, deg=3, coefMin=0.5,
                    coefMax=1.5, noiseMin=1, noiseMax=2, seed=1)

write.csv(sim$data,file = "rCausalMGM_sim_data_large.csv", row.names=FALSE)


write.csv( str_split(sim$graph$edges, pattern = " ",simplify=T),
          file = "rCausalMGM_sim_graph_large.csv",
          col.names = FALSE,
          row.names=FALSE)
