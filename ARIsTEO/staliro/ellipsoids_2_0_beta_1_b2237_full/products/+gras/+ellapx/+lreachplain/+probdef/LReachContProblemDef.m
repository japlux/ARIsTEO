% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
classdef LReachContProblemDef<gras.ellapx.lreachplain.probdef.AReachContProblemDef
    methods
        function self=LReachContProblemDef(aCMat,bCMat,pCMat,pCVec,...
                x0Mat,x0Vec,tLims)
            %
            self=self@gras.ellapx.lreachplain.probdef.AReachContProblemDef(...
                aCMat,bCMat,pCMat,pCVec,x0Mat,x0Vec,tLims);
        end
    end
end



