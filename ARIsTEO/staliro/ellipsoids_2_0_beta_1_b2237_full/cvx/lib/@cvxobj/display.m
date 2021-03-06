% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
function display( x )
long = ~isequal(get(0,'FormatSpacing'),'compact');
if long, disp( ' ' ); end
disp([inputname(1) ' =']);
if long, disp( ' ' ); end
disp(x,'    ')
if long, disp( ' ' ); end

% Copyright 2012 CVX Research, Inc.
% See the file COPYING.txt for full copyright information.
% The command 'cvx_where' will show where this file is located.
