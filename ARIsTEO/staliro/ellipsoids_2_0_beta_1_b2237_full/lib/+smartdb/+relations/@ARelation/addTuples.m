% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
function addTuples(self,varargin)
% ADDTUPLES - adds a set of new tuples to the relation        
%
% Usage: addTuplesInternal(self,varargin)
%
% input:
%   regular:
%       self: ARelation [1,1] - class object
%       SData: struct [1,1] - structure with values of all fields  for all 
%        tuples
%   optional:
%       SIsNull: struct [1,1] - structure of fields with is-null
%         information for the field content, it can be logical for plain  
%         real numbers of cell of logicals for cell strs or cell of cell of 
%         str for more complex types
%
%       SIsValueNull: struct [1,1] - structure with logicals determining 
%         whether value corresponding to each field and each tuple is null  
%         or not
%
%   properties:
%       checkConsistency: logical[1,1], if true, a consistency between the 
%          input structures is not checked, true by default
%         
%
% $Author: Peter Gagarinov  <pgagarinov@gmail.com> $	$Date: 2011-11-10 $ 
% $Copyright: Moscow State University,
%            Faculty of Computational Mathematics and Computer Science,
%            System Analysis Department 2011 $
%
%
self.addTuplesInternal(varargin{:});