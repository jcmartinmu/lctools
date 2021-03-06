gwr.cv <- function(bw, formula, dframe, obs, kernel, dmatrix)
{  
  Gl.Model <- eval(substitute(lm(formula, data = dframe)))
  RNames<-names(Gl.Model$coefficients)
  ModelVarNo <-length(Gl.Model$coefficients)
  
  LM_LEst<-as.data.frame(setNames(replicate(ModelVarNo,numeric(0), simplify = F), RNames[1:ModelVarNo]))
  LM_GofFit<-data.frame(y=numeric(0), LM_yfit=numeric(0), LM_Res=numeric(0))
  
  if(kernel == 'adaptive')
    {
       Ne <- bw
    } 
  
  for(m in 1:obs){
      
      #Get the data 
      DNeighbour <- dmatrix[,m]
      DataSet <- data.frame(dframe, DNeighbour=DNeighbour)

      #Sort by distance
      DataSetSorted<- DataSet[order(DataSet$DNeighbour),]
      
      if(kernel == 'adaptive')
      { 
        #Keep Nearest Neighbours
        SubSet <- DataSetSorted[1:Ne,]
        Kernel_H <- max(SubSet$DNeighbour)
      } 
      else 
      { 
        if(kernel == 'fixed')
        {
          SubSet <- subset(DataSetSorted, DNeighbour <= bw)
          Kernel_H <- bw
        }
      }
      
      #Bi-square weights
      Wts<-(1-(SubSet$DNeighbour/Kernel_H)^2)^2
      
      #Leave-one-out
      Wts[1]=0
      
      #Calculate WLM
      Lcl.Model<-eval(substitute(lm(formula, data = SubSet, weights=Wts)))
      
      #Store in table
      LM_LEst[m,]<-Lcl.Model$coefficients
      LM_GofFit[m,1]<-Gl.Model$model[m,1]
      LM_GofFit[m,2]<-sum(Gl.Model$model[m,2:ModelVarNo] * Lcl.Model$coefficients[2:ModelVarNo]) + Lcl.Model$coefficients[[1]]
      LM_GofFit[m,3]<-LM_GofFit[m,1] - LM_GofFit[m,2]
    }
 
  RSS <- sum(LM_GofFit$LM_Res^2)
  
  return(RSS)
}

gwr.bw<-function(formula, dframe, coords, kernel, algorithm="exhaustive", optim.method="Nelder-Mead", b.min=NULL, b.max=NULL, step=NULL) {
  
  Obs <- nrow(dframe)
  DistanceTable <- dist(coords)
  Dij <- as.matrix(DistanceTable)
    
  if(kernel == 'adaptive') 
    {
      if (is.null(b.max) || b.max > Obs) {b.max <- Obs}
      if (is.null(b.min)) {b.min <- 30} 
      
      b <- b.min:b.max
    }
  else 
    { 
      if(kernel == 'fixed')
        {
        Dij.max <- max(Dij)
        Dij.min <- min(Dij[Dij>0])
        
        if (is.null(b.max) || b.max > Dij.max) {b.max <- Dij.max}
        if (is.null(b.min)) {b.min <- Dij.min}  
        if (is.null(step)) {step <- (b.max - b.min)/99}
        
        b<-seq(from=b.min, to=b.max+step, by=step)
        }
    } 
  cat("\nNumber of Observations:", Obs)

  if (algorithm == "exhaustive")
    {
        CVs <- matrix(data=NA, nrow=length(b), ncol=2)
        counter <- 1
        
        for(bw in b)
          {
          CV <- gwr.cv(bw, formula, dframe, Obs, kernel, Dij)
          cat("\nBandwidth: ", bw, "CV: ", CV)
          CVs[counter,1] <- bw
          CVs[counter,2] <- CV
          counter<-counter+1
          }
        plot(CVs[,1],CVs[,2], xlab="Bandwidth", ylab="Cross-Validation score")
        CV<-min(CVs[,2])
        bw <- round(CVs[which(CVs[,2]==CV),1],0)
        out<-list(bw=bw, CV=CV, CVs=CVs)
      } 
  else 
  { 
    if (algorithm == "heuristic") 
      { if(optim.method=="Brent")
      
        {
        opt <- optim(b.min, gwr.cv, formula=formula, dframe=dframe, kernel=kernel, obs=Obs,
                     dmatrix=Dij, method=optim.method, lower = b.min, upper = b.max)        
        
        }
        else{
          opt <- optim(b.min, gwr.cv, formula=formula, dframe=dframe, kernel=kernel, obs=Obs,
                       dmatrix=Dij, method=optim.method)        
      }

        
      }
      bw <- round(opt$par,0)
     out <- list(bw=bw, CV=opt$value)
    #out<-opt
  }

  return(out)
}
