% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
function copyconf(confName,toConfName)
confRepoMgr=gras.ellapx.uncertcalc.conf.ConfRepoMgr();
confRepoMgr.copyConf(confName,toConfName);