% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
function y = pow_p( x, p )

%POW_P   Positive branch of the power function.
%   POW_P(X,P) computes a convex or concave branch of the power function:
%           P < 0: POW_P(X,P) = X.^P if X >  0, +Inf otherwise
%      0 <= P < 1: POW_P(X,P) = X.^P if X >= 0, -Inf otherwise
%      1 <= P    : POW_P(X,P) = X.^P if X >= 0, +Inf otherwise
%   Both P and X must be real.
%
%   Disciplined convex programming information:
%       The geometry of POW_P(X,P) depends on the precise value of P,
%       which must be a real constant:
%                P < 0: convex  and nonincreasing; X must be concave.
%           0 <= P < 1: concave and nondecreasing; X must be concave.
%           1 <= P    : convex  and nonmonotonic;  X must be affine.
%       In all cases, X must be real.

error( nargchk( 2, 2, nargin ) ); %#ok
if ~isnumeric( x ) || ~isreal( x ) || ~isnumeric( p ) || ~isreal( p ),
    error( 'Arguments must be real.' );
end
y  = x .^ p;
y( x < 0 & ( p >= 0 & p <  1 ) ) = -Inf;
y( x < 0 & ( p <  0 | p >= 1 ) ) = +Inf;

% Copyright 2012 CVX Research, Inc. 
% See the file COPYING.txt for full copyright information.
% The command 'cvx_where' will show where this file is located.
