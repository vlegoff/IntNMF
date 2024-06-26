# Main function
nmf.mnnals <- function(dat=dat,k=k,maxiter=200,st.count=20,n.ini=30,ini.nndsvd=TRUE,seed=TRUE,
						wt=if(is.list(dat)) rep(1,length(dat)) else 1)
{
#wt: user specified weight for each data, default is: each data is weighted equally
#nmf.mnnals: Nonnegative Matrix Factorization of Multiple data using Nonnegative Alternating Least Square
if(seed) set.seed(12345) # Note: set 'seed=F' inside "nmf.opt.k" function to find optimum k.
if(!is.list(dat) & length(wt)>1) stop("Weight is not applicable for single data")
if (!is.list(dat)) dat <- list(dat)
n <- nrow(dat[[1]])
n.dat <- length(dat)
if (n.dat!=length(wt)) stop("Number of weights must match number of data")
for (i in 1:n.dat)  assign(paste("d",i,sep=""),eval(parse(text=paste("dat[[",i,"]]",sep=""))))
for (i in 1:n.dat){
	if (!all(eval(parse(text=paste("d",i,sep="")))>=0))
		stop(paste("All values must be positive. There are -ve entries in dat",i,sep=""))}
min.f.WH <- NULL
W.list <- NULL
for (i in 1:length(dat)) assign(paste("H",i,".list",sep=""),NULL)
convergence.list <- NULL
consensus.list <- NULL

for (j in 1:n.ini)
		{
		abs.diff <- NA
		consensus <- matrix(0,n,n)
		# Initialization of W
		#--------------------------------
		# 1. Using nndsvd by Boutsidis and Gallopoulos, 2008
		if (j==1 && ini.nndsvd){
			for (i in 1:n.dat) assign(paste("tmp.H",i,sep=""),.nndsvd.internal(dat[[i]], k, flag=0)$H)
			tmp.H <- NULL
			for (i in 1:n.dat) tmp.H <- c(tmp.H,list(eval(parse(text=paste("tmp.H",i,sep="")))))
			W <- W.fcnnls(x=tmp.H, y=dat, weight=wt)$coef
			W <- t(W)
			rm(tmp.H)
			rm(list=paste("tmp.H",1:length(dat),sep=""))
		# 2. Random within mininum and maximum limits of data
			} else {
			W <- matrix(runif(n*k,min=min(unlist(dat)),max=max(unlist(dat))),nrow=n)}

		connect.old <- matrix(0,nrow=n,ncol=n)     # Connectivity matrix
		count <- 1
		iter <- 1
		convergence <- NULL
		while ((iter < maxiter) && (count < st.count)){
			W <- sweep(W,2,pmax(sqrt(colSums(W^2)),.Machine$double.eps),"/")
			# Solve for Hi's using non negativity constraint least squares
			for (i in 1:n.dat) assign(paste("H",i,sep=""),H.fcnnls(W,dat[[i]])$coef)
			tmp.H <- NULL
			for (i in 1:n.dat) tmp.H <- c(tmp.H,list(eval(parse(text=paste("H",i,sep="")))))
			# Solve for W using non negativity constraint least squares
			W <- W.fcnnls(x=tmp.H, y=dat, weight=wt)$coef
			W <- t(W)
			rm(tmp.H)

			# Compute the following for each iteration
			# (i) abs.diff : Change in reconstruction error
			# (ii) f.WH    : Objective function
			if (iter==1) {for (i in 1:n.dat) assign(paste("d",i,".old",sep=""),W %*% eval(parse(text=paste("H",i,sep=""))))
				f.WH <- 0;
				for (i in 1:n.dat) f.WH <- f.WH + wt[i]*sum((eval(parse(text=paste("d",i,sep="")))
													- eval(parse(text=paste("d",i,".old",sep=""))))^2)
			} else {
				for (i in 1:n.dat) assign(paste("d",i,".new",sep=""),W %*% eval(parse(text=paste("H",i,sep=""))))
				abs.diff <- 0
				for (i in 1:n.dat) abs.diff <- abs.diff + sum(abs(eval(parse(text=paste("d",i,".new",sep="")))
													- eval(parse(text=paste("d",i,".old",sep="")))))/sum(eval(parse(text=paste("d",i,".old",sep=""))))
				for (i in 1:n.dat) assign(paste("d",i,".old",sep=""),eval(parse(text=paste("d",i,".new",sep=""))))
				f.WH <- 0;
				for (i in 1:n.dat) f.WH <- f.WH + wt[i]*sum((eval(parse(text=paste("d",i,sep="")))
													- eval(parse(text=paste("d",i,".new",sep=""))))^2)}

			f.WH <- sqrt(f.WH)
			clust.mem <- apply(W,1,which.max)
			tmp1 <- matrix(rep(clust.mem,n),nrow=n,byrow=T)
			tmp2 <- matrix(rep(clust.mem,n),nrow=n,byrow=F)

			connect.new <- ifelse(tmp1==tmp2,1,0)
			if (all(connect.new==connect.old)) count <- count + 1    # Accumulate count
			else count <- 0                                          # Restart count
			convergence <- rbind(convergence,c(iter,count,ifelse(all(connect.new==connect.old),1,0),abs.diff,f.WH))
			consensus <- consensus + connect.new
			connect.old <- connect.new
			iter <- iter + 1
			tol <- abs.diff
			rm(tmp1,tmp2,clust.mem,connect.new)
			}
		colnames(convergence) <- c("iter","count","stability","abs.diff","f.WH")
		consensus <- consensus/(iter-1)
		# Save all the min.abs.diff values, and make list of all W,H, convergence and consensus matrices
		min.f.WH <- c(min.f.WH,f.WH)
		W.list <- c(W.list,list(W))
		for (i in 1:n.dat) assign(paste("H",i,".list",sep=""), c(eval(parse(text=paste("H",i,".list",sep=""))),
										list(eval(parse(text=paste("H",i,sep=""))))))
		convergence.list <- c(convergence.list,list(convergence))
		consensus.list <- c(consensus.list,list(consensus))

		# Save memory space by saving only the optimum results.
		# i.e. remove the non optimum results during the iterative steps.
		H.list <- NULL
		for (i in 1:n.dat) H.list <- c(H.list,list(eval(parse(text=paste("H",i,".list",sep="")))))
		names(H.list) <- paste("H",1:n.dat,".list",sep="")

		if(j>1){
		if (min(min.f.WH[-j]) <= min.f.WH[j]){
			W.list[j] <- "Not an Optimum Solution"
			for (i in 1:n.dat) H.list[[i]][j] <- "Not an Optimum Solution"
			convergence.list[j] <- "Not an Optimum Solution"
			consensus.list[j] <- "Not an Optimum Solution"
		} else {
                        prevmin = which(W.list[-j] != "Not an Optimum Solution")
			W.list[prevmin] <- "Not an Optimum Solution"
			for (i in 1:n.dat) H.list[[i]][prevmin] <- "Not an Optimum Solution"
			convergence.list[prevmin] <- "Not an Optimum Solution"
			consensus.list[prevmin] <- "Not an Optimum Solution"}}
		}
	# Select the factorization (W and H) that leads to the lowest objective function 'f.WH'
        selected = which.min(min.f.WH)
        # safeguard in case everything goes wrong
        if(W.list[selected]=="Not an Optimum Solution") {
            warning("min criterion is not an optimum solution")
            selected = which(W.list!="Not an Optimum Solution")[1]
        }
	W <- W.list[[selected]]
	H <- NULL
	if(n.dat > 1){
		for (i in 1:n.dat){
			assign(paste("H",i,sep=""),H.list[[i]][[selected]])
			H <- c(H,list(eval(parse(text=paste("H",i,sep="")))))}
		names(H) <- paste("H",1:n.dat,sep="")
	} else {
		assign("H",H.list[[i]][[selected]])
		names(H) <- "H"}
	consensus <- consensus.list[[selected]]
	dimnames(consensus) <- list(rownames(W),rownames(W))
	convergence <- convergence.list[[selected]]
	# Compute cluster membership
	clusters <- apply(W,1,which.max)
	# Output the following results
	output <- list(consensus=consensus,W=W,H=H,convergence=convergence,min.f.WH=min.f.WH,clusters=clusters)
	return(output)
}
