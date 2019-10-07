% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
  T  = 5;
  w  = 2;
  A  = {'0' '1' '0' '0' '0'
        '-2' '0' '0' '0' '0'
	'0' '0' '-cos(2*t)' '0' '0'
	'0' '0' '0' '0' '1.5'
	'0' '0' '0' '-1' '0'};
  %A  = [0 1 0 0 0; -w 0 0 0 0; 0 0 -0.5 0 0; 0 0 0 0 1.5; 0 0 0 -1 0];
  B  = eye(5);
  C  = eye(5);
  U  = ellipsoid([9 0 0 0 0; 0 2 0 0 0; 0 0 4 0 0; 0 0 0 4 0; 0 0 0 0 9]);
  V  = ellipsoid([1 0 0 0 0; 0 2 0 0 0; 0 0 3 0 0; 0 0 0 2 0; 0 0 0 0 1]);
  o.save_all = 1;
  s  = linsys(A, B, U, C, V);
  
  X0 = ellipsoid([10; -1; 1; 0; -10], 36*eye(5));
  L0 = [0 1 -1 0 1; 0 1 1 0 0; 1 0 0 1 -1]';
  L0 = [0 1 -1 0 1; 0 1 1 0 0]';
  o.save_all = 1;
  rs = reach(s, X0, L0, [1 T],o);
