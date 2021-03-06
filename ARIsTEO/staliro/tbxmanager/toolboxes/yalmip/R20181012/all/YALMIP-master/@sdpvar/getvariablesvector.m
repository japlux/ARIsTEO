% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
function x_var = getvariablesvector(x)

x_var = zeros(x.n,1);
base = x.basis(:,2:end);
vars = x.lmi_variables;
[i,j,s] = find(base);
x_var = vars(j);
x_var = x_var(:);