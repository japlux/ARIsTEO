% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
classdef MatrixPInvFunc<gras.mat.AMatrixUnaryOpFunc
    methods
        function self=MatrixPInvFunc(lMatFunc)
            %
            self=self@gras.mat.AMatrixUnaryOpFunc(lMatFunc,@pinv);
            %
            self.nRows = lMatFunc.getNCols();
            self.nCols = lMatFunc.getNRows();
            self.nDims = lMatFunc.getDimensionality();
        end
    end
end
