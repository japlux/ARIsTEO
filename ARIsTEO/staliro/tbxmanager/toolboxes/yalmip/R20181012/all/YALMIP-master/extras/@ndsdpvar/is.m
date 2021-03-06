% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
function YESNO = is(X,property,additional)
%IS Check property of variable.
%   d = IS(x,property) returns 1 if 'property' holds
%
%   Properties possible to test are: 'complex'

switch property
    case 'complex'
        YESNO = ~isreal(X.basis);
    otherwise
        error('Wrong input argument.');
end
