% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
% Maximize stopband attenuation of a linear phase lowpass FIR filter
% "Filter design" lecture notes (EE364) by S. Boyd
% (figures are generated)
%
% Designs a linear phase FIR lowpass filter such that it:
% - minimizes maximum stopband attenuation
% - has a constraint on the maximum passband ripple
%
% This is a convex problem (when sampled it can be represented as an LP).
%
%   minimize   max |H(w)|                     for w in the stopband
%       s.t.   1/delta <= |H(w)| <= delta     for w in the passband
%
% where H is the frequency response function and variable is
% h (the filter impulse response). delta is allowed passband ripple.
%
% Written for CVX by Almir Mutapcic 02/02/06

%********************************************************************
% user's filter specifications
%********************************************************************
% filter order is 2n+1 (symmetric around the half-point)
n = 10;

wpass = 0.12*pi;        % passband cutoff freq (in radians)
wstop = 0.24*pi;        % stopband start freq (in radians)
max_pass_ripple = 1;    % (delta) max allowed passband ripple in dB
                        % ideal passband gain is 0 dB

%********************************************************************
% create optimization parameters
%********************************************************************
N = 30*n;                              % freq samples (rule-of-thumb)
w = linspace(0,pi,N);
A = [ones(N,1) 2*cos(kron(w',[1:n]))]; % matrix of cosines

% passband 0 <= w <= w_pass
ind = find((0 <= w) & (w <= wpass));    % passband
Lp  = 10^(-max_pass_ripple/20)*ones(length(ind),1);
Up  = 10^(max_pass_ripple/20)*ones(length(ind),1);
Ap  = A(ind,:);

% transition band is not constrained (w_pass <= w <= w_stop)

% stopband (w_stop <= w)
ind = find((wstop <= w) & (w <= pi));   % stopband
As  = A(ind,:);

%********************************************************************
% optimization
%********************************************************************
% formulate and solve the linear-phase lowpass filter design
cvx_begin
  variable h(n+1,1);

  minimize( max( abs( As*h ) ) )
  subject to
    % passband bounds
    Lp <= Ap*h;
    Ap*h <= Up;
cvx_end

% check if problem was successfully solved
disp(['Problem is ' cvx_status])
if ~strfind(cvx_status,'Solved')
  return
else
  fprintf(1,'The minimum attenuation in the stopband is %3.2f dB.\n\n',...
          20*log10(cvx_optval));
  % construct the full impulse response
  h = [flipud(h(2:end)); h];
end

%********************************************************************
% plots
%********************************************************************
figure(1)
% FIR impulse response
plot([0:2*n],h','o',[0:2*n],h','b:')
xlabel('t'), ylabel('h(t)')

figure(2)
% frequency response
H = exp(-j*kron(w',[0:2*n]))*h;
% magnitude
subplot(2,1,1)
plot(w,20*log10(abs(H)),...
     [0 wpass],[max_pass_ripple max_pass_ripple],'r--',...
     [0 wpass],[-max_pass_ripple -max_pass_ripple],'r--');
axis([0,pi,-50,10])
xlabel('w'), ylabel('mag H(w) in dB')
% phase
subplot(2,1,2)
plot(w,angle(H))
axis([0,pi,-pi,pi])
xlabel('w'), ylabel('phase H(w)')
