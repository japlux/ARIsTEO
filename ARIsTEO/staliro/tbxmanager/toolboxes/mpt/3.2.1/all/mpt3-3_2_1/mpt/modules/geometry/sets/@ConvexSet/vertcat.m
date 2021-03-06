% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
function y=vertcat(varargin)
% Vertical concatenation of ConvexSet objects

% Since concatenation is a time-critical operation which must be
% implemented as efficiently as possible:
% * use cellfun('isempty') instead of cellfun(@isempty)
% * don't use cellfun(..., 'UniformOutput', false), it's slow due to
% parsing of the options!
% * don't use anonymous function handles in cellfun(), it's slow!
% * don't use "parfor", it's slow!
% * don't use unique(cell), it's slow!

% delete empty entries
e = cellfun('isempty', varargin);
varargin(e)=[];

% check whether all arguments are of the same type
first_class = class(varargin{1});
for i = 2:numel(varargin)
	if ~isequal(class(varargin{i}), first_class)
		error('Only the same sets can be concatenated.');
	end
end

% make sure that each argument is a column array
for i = 1:length(varargin)
	if size(varargin{i}, 2) > 1
		varargin{i} = varargin{i}(:);
	end
end

% concatenate arguments vertically
y = builtin('vertcat',varargin{:});

end
