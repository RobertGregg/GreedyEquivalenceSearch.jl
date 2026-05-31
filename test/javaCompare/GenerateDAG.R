library(rCausalMGM)
library(stringr)


###################
#Small Dataset
###################
sim <- simRandomDAG(n=1000, p=50, discFrac=0.0, deg=3, coefMin=0.5,
                    coefMax=1.5, noiseMin=1, noiseMax=2, seed=1)

write.csv(sim$data,file = "simulatedDAGs/small_sim_data.csv", row.names=FALSE)


write.csv(sim$graph$edges,
          file = "simulatedDAGs/small_sim_graph.csv",
          col.names = FALSE,
          row.names=FALSE)


###################
#Medium Dataset
###################
sim <- simRandomDAG(n=1000, p=100, discFrac=0.0, deg=3, coefMin=0.5,
                    coefMax=1.5, noiseMin=1, noiseMax=2, seed=1)

write.csv(sim$data,file = "simulatedDAGs/medium_sim_data.csv", row.names=FALSE)


write.csv(sim$graph$edges,
          file = "simulatedDAGs/medium_sim_graph.csv",
          col.names = FALSE,
          row.names=FALSE)



###################
#Large Dataset
###################

sim <- simRandomDAG(n=1000, p=500, discFrac=0.0, deg=3, coefMin=0.5,
                    coefMax=1.5, noiseMin=1, noiseMax=2, seed=1)

write.csv(sim$data,file = "simulatedDAGs/large_sim_data.csv", row.names=FALSE)


write.csv( str_split(sim$graph$edges, pattern = " ",simplify=T),
          file = "simulatedDAGs/large_sim_graph.csv",
          col.names = FALSE,
          row.names=FALSE)
