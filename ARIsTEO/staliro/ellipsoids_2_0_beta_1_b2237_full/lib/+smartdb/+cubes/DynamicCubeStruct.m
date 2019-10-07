% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
classdef DynamicCubeStruct<smartdb.cubes.CubeStruct&...
        smartdb.cubes.DynamicCubeStructAppliance
    methods (Access=protected,Hidden)
        function initialize(self,varargin)
            self.parseAndAssignFieldProps(varargin{:});
        end
    end
    methods
        function self=DynamicCubeStruct(varargin)
            self=self@smartdb.cubes.CubeStruct(varargin{:});
        end
    end
end