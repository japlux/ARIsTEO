% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
%===============================================================================
%
% Title:        hyparr
%                                                             
% Project:      Transformation of HYSDEL model into PWA model
%
% Purpose:      Dervive hyperplane arrangement
%
% Input:        Hyp: hyperplanes Hyp.A(i,:)*x = Hyp.B(i), for i = 1...rows(Hyp.A)
%                    that define a hyperplane arrangement
%               P: constraints P.A*x <= P.B define polyhedron
%                  P=[] is possible 
%               dom: constraints dom.A*x <= dom.B defines the domain
%                    these constraints are only used if dom.constr exists
%               lpsolver
%               verbose
%               minR: minimal required radius of Chebycheff ball of polyhedra
%
% Output:       delta: hyperplane arrangement, or the markings of the regions 
%                      generated by the hyperplanes Hyp, where delta(:,j) 
%                      represents the j-th region of the arrangement as a 
%                      {-1, 1} vector. 
%                      Only the markings of the regions having feasible points 
%                      in P and dom are returned.
%
%               Example: 
%                   delta = [1  1 -1;
%                            1 -1 -1] 
%                   means that there were 2 hyperplanes and that they induce 3 
%                   polyhedra: 
%                   1. A x <= B;
%                   2. A(1,:) <= B(1),  A(2,:) >= B(2);
%                   3. A(1,:) >= B(1),  A(2,:) >= B(2);
%
%               Note: This definition is contrary to the one in optMerge 
%                     (and Ziegler)
%
% Comments:     By default, the reverse search tool by Komei Fukuda is currently 
%               not used, as it does not work realiably for large problems.
%               Instead, the feasibility of the regions is checked by solving LPs.
%               The efficiency is improved by the following means:
%               * if dom.constr=1, only regions with feasible points in dom are 
%                 considered
%               * large hyperplane arrangements are stored in the function 
%               * in a last step, only the regions with feasible points in P are 
%                 returned (thus allowing the storage of already computed
%                 hyperplane arrangements)
%
% Authors:      Tobias Geyer <geyer@control.ee.ethz.ch>, Fabio Torrisi
                                                                      
% History:      date        ver subject                                       
%               2002.09.23  1.0 initial version
%               2003.05.09  1.1 code rewritten, storage of computed hyperplane arrangements
%               2004.06.16  2.0 iterative computation based on preliminary markings
%
% Requires:     zonotope,
%               tg_polyreduce, mpt_intersectHP1
%
% Contact:      Tobias Geyer
%               Automatic Control Laboratory
%               ETH Zentrum, CH-8092 Zurich, Switzerland
%
%               geyer@aut.ee.ethz.ch
%
%               Comments and bug reports are highly appreciated
%
%===============================================================================

% (C) 2004 Michal Kvasnica, Automatic Control Laboratory, ETH Zurich,
%          kvasnica@control.ee.ethz.ch
% (C) 2003-2004 Tobias Geyer, Automatic Control Laboratory, ETH Zurich,
%          geyer@control.ee.ethz.ch

% ---------------------------------------------------------------------------
% Legal note:
%          This program is free software; you can redistribute it and/or
%          modify it under the terms of the GNU General Public
%          License as published by the Free Software Foundation; either
%          version 2.1 of the License, or (at your option) any later version.
%
%          This program is distributed in the hope that it will be useful,
%          but WITHOUT ANY WARRANTY; without even the implied warranty of
%          MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%          General Public License for more details.
% 
%          You should have received a copy of the GNU General Public
%          License along with this library; if not, write to the 
%          Free Software Foundation, Inc., 
%          59 Temple Place, Suite 330, 
%          Boston, MA  02111-1307  USA
%
% ---------------------------------------------------------------------------


function delta = hyparr2(Hyp, P, dom, Opt)

global mptOptions

if ~isstruct(mptOptions)
    mpt_error;
end

% hyperplane arrangement as persistent 
% = local to the function hyparr yet their values are 
%   retained in memory between calls to the function.  
persistent HA

if nargin==0,
    clear HA
    return
end

% complement the inputs
if isempty(P), P.A = []; P.B = []; end;
if ~isfield(dom, 'constr'), dom.constr=0; end;
if nargin < 4, Opt = []; end;

if ~isfield(Opt, 'lpsolver')
    Opt.lpsolver = mptOptions.lpsolver;
end;
if ~isfield(Opt, 'verbose')
    Opt.verbose = 0;
end;
if ~isfield(Opt, 'tol_minR');
    Opt.tol_minR = 0;
end;
if ~isfield(Opt, 'sizeInitialHA');
    Opt.sizeInitialHA = 5;
end;
Opt.verbose=0;

% LP solver:
% lpsolver=0: uses E04MBF.m
% lpsolver=1: uses linprog.m (MATLAB)
% lpsolver=2: uses CPLEX



% normalize hyperplanes A*x=B
norm = sqrt(sum(Hyp.A.*Hyp.A,2));       % using: Euclidean norm
% norm = max(abs(Hyp.A),[],2);          % optional: Infinity norm
if min(norm)==0, error('There is at least one badly defined hyperplane!'); end
Hyp.A = Hyp.A .* kron(1./norm, ones(1,size(Hyp.A,2)));
Hyp.B = Hyp.B./norm;

% restrict hyperplane arrangement a priori to dom.H*[xr; ur] <= dom.K?
if dom.constr 
    % add the bounds on xr-ur space (given at the declaration of
    % the xr and ur variables in hysdel) as constraints.
    Hdom = dom.H;
    Kdom = dom.K;
else
    % don't add them
    Hdom = [];
    Kdom = [];
end;

delta = [];
nc = length(Hyp.B); % number of constraints / hyperplanes

% check out different approaches:
% delta = hyparr_test(Hyp, P, dom, Opt.verbose, -1);

if nc >= 4

    % we have at least four hyperplanes
    % reusing already computed hyperplane arrangements is thus very reasonable
    
    % is Hyp.A*x=Hyp.B an entry of HA?
    % (= has the hyperplane arrangement for Hyp.A*x=Hyp.B been already computed?)
    i = 1;
    while i <= length(HA)
        if length(HA{i}.B) == nc
            % same number of hyperplanes
            if all( HA{i}.B == Hyp.B )
                % B vectors are the same
                if all (HA{i}.A == Hyp.A )
                    % also A matrices are the same
                    % --> we have found an entry for A*x=B
                    delta = HA{i}.delta;
                    %if verbose, fprintf('  found hyperplane arrangement with %1i hyperplanes\n', length(Hyp.B)); end;
                    if Opt.verbose==2, fprintf('f(%1i) ', length(Hyp.B)); end;
                    break
                end;
            end;
        end;
        i = i+1;
    end;
    
    if isempty(delta)
        % derive hyperplane arrangement restricted to the domain (if set)
        % using the iterative approach (efficient for large hyperplane arrangements)
        t0 = clock;
        if length(Hyp.B) <= Opt.sizeInitialHA
            if Opt.verbose>1,
                disp('computing markings using iter_lp')
            end
            delta = iter_lp(Hyp.A, Hyp.B, Hdom, Kdom, Opt);
        else
            if Opt.verbose>0,
                fprintf('computing markings using perlimM with %i initial hyperplanes\n',Opt.sizeInitialHA);
            end
            delta = prelimM(Hyp.A, Hyp.B, Hdom, Kdom, Opt);
        end;
        if Opt.verbose==2, fprintf('c(%0.2fs) ', etime(clock, t0)); end;
        
        % store in HA
        HA{end+1}.A = Hyp.A;
        HA{end}.B = Hyp.B;
        HA{end}.delta = delta;
    end;
    
    % extract the polyhedra that are within the polyhedron P,
    % i.e. restrict polyhedra a posteriori to P.A*[xr; ur] <= P.B
    t0 = clock;
%     i = 1;
%     while i <= size(delta,2)
%         % consider polyhedron given by the marking delta(i,:)
%         m = delta(:,i);
%         
%         % get the center x and the radius r of the polyhedron 
%         [x,r] = polyinnerball([diag(m)*Hyp.A; P.A],[diag(m)*Hyp.B; P.B], lpsolver);
%         if r >= tol_minR, i = i+1;
%         else          delta(:,i) = []; 
%         end
%     end
    keepInd = [];
    for i = 1:size(delta,2)
        % consider polyhedron given by the marking delta(i,:)
        m = delta(:,i);
        
        % get the center x and the radius r of the polyhedron 
        [x,r] = polyinnerball([diag(m)*Hyp.A; P.A],[diag(m)*Hyp.B; P.B], Opt.lpsolver);
        if r >= Opt.tol_minR, keepInd(end+1) = i; end;
    end
    delta = delta(:,keepInd);
    if Opt.verbose==2, fprintf('r(%0.2fs) ', etime(clock, t0)); end;

else
    
    % we have less than four hyperplanes
    % it is faster to recompute the hyperplane arrangement each time newly
    % taking into account the bounds given by P and dom 
    delta = std_lp(Hyp.A, Hyp.B, [P.A; Hdom], [P.B; Kdom], Opt.lpsolver, Opt.tol_minR);
    
end;



% --------------------------------------------------------------------

function delta = std_lp(A, B, H, K, lpsolver, minR)
% given the hyperplanes A*x = B
% enumerate all regions in the polyhedron H*x<=K
delta = [];
nc = length(B); % number of constraints / hyperplanes
for i = 0:2^nc-1,
    m = + ones(nc,1) - 2*(dec2bin(i,nc)-'0')';    % derive the i-th marking
    
    % get the center x and the radius r of the polyhedron
    [x,r] = polyinnerball([diag(m)*A; H],[diag(m)*B; K], lpsolver);
    if r >= minR, delta(:,end+1) = m; end
end




% --------------------------------------------------------------------

function D = iter_lp(A, B, H, K, Opt)
% given the hyperplanes A*x = B
% enumerate all regions *iteratively* in the polyhedron H*x<=K

% idea:
% build hyperplane arrangement step by step adding one hyperplane per step.
% Thus, each polyhedron is possibly cut into two. Only the feasible ones are 
% kept at every step. Feasible means, that the radius of their Chebycheff
% ball is larger than minR

if Opt.verbose==2
    fprintf('  adding hyperplane #i / %i:\n ', length(B));
end;

% initial step: first hyperplane
D = [];

% '-'
[x,r] = polyinnerball([(-1)*A(1,:); H], [-B(1); K], Opt.lpsolver);
if r >= Opt.tol_minR, D(:,end+1) = -1; end

% '+'
[x,r] = polyinnerball([A(1,:); H], [B(1); K], Opt.lpsolver);
if r >= Opt.tol_minR, D(:,end+1) = +1; end

% % second step: remaining hyperplanes
% for i = 2:length(B),
%     % add i-th hyperplane to the markings in D
%     D_augm = [];
%     for j = 1:size(D,2)
%         % add i-th hyperplane to the j-th polyhedron in D
%         m = D(:,j);
%         % -
%         [x,r] = polyinnerball([diag([m;-1])*A(1:i,:); H], [diag([m;-1])*B(1:i); K], lpsolver);
%         if r >= minR, D_augm(:,end+1) = [m;-1]; end
%         % +
%         [x,r] = polyinnerball([diag([m;+1])*A(1:i,:); H], [diag([m;+1])*B(1:i); K], lpsolver);
%         if r >= minR, D_augm(:,end+1) = [m;+1]; end
%     end;
%     D = D_augm;
% end

% second step: remaining hyperplanes
for i = 2:length(B),
    
    if Opt.verbose==2, fprintf(' #%i', i); end;
    
    % reserve memory for D_augm to speed up the algorithm
    D_augm = NaN*ones(i,2*size(D,2));
    len = 0;
    
    % add i-th hyperplane to the markings in D
    for j = 1:size(D,2)
        
        % add i-th hyperplane to the j-th polyhedron in D
        m = D(:,j);
        
        % -
        [x,r] = polyinnerball([diag([m;-1])*A(1:i,:); H], [diag([m;-1])*B(1:i); K], Opt.lpsolver);
        if r >= Opt.tol_minR, 
            len = len+1;
            D_augm(:,len) = [m;-1]; 
        end
        
        % +
        [x,r] = polyinnerball([diag([m;+1])*A(1:i,:); H], [diag([m;+1])*B(1:i); K], Opt.lpsolver);
        if r >= Opt.tol_minR, 
            len = len+1;
            D_augm(:,len) = [m;+1]; 
        end
    end;
    D = D_augm(:,1:len);
end

return





% --------------------------------------------------------------------

function D = prelimM(A, B, H, K, Opt)
Hyp.A = A;
Hyp.B = B;
dom.A = H;
dom.B = K;
% given the hyperplanes Hyp.A*x = Hyp.B
% enumerate all regions *iteratively* in the polyhedron dom.A*x<=dom.B

% In this function, we use the definition of Ziegler for the sign
% convection of the markings. This is contrary to the rest of the file, in
% particular to iter_lp etc.

% Overview of Algorithm:
% ----------------------
% ...

% tolerances:
tol.intersect = 1e-9;      % when using intersectHP
tol.coeff = 1e-6;          % when dealing with coefficients of hyperplanes
tol.round = 1e-9;
tol.polyreduce = 1e-6;     % when using polyreduce 

% parameters
Opt.safeMode = 0;


% split hyperplane arrangement into an initial one and the rest
HypInit.A = Hyp.A(1:Opt.sizeInitialHA,:);
HypInit.B = Hyp.B(1:Opt.sizeInitialHA,:);

HypRest.A = Hyp.A(Opt.sizeInitialHA+1:end,:);
HypRest.B = Hyp.B(Opt.sizeInitialHA+1:end,:);

% for the initial HA: compute the markings
D = (-1)*iter_lp(HypInit.A, HypInit.B, dom.A, dom.B, Opt);

% compute the corresponding polyhedra
dim = size(Hyp.A, 2);   % dimension (number of variables per hyperplane)
Hi = []; Ki = [];
for i = 1:size(D,2)
    % marking
    m = D(:,i);
    
    % raw polyhedron
    H = [(-1)*diag(m)*HypInit.A; dom.A];
    K = [(-1)*diag(m)*HypInit.B; dom.B];
    
    % remove redundant facets
    [H, K, isempty, keptrows] = tg_polyreduce(H, K, tol.polyreduce, Opt.lpsolver, 1);
    if isempty, 
        disp('polyhedron is empty');
        continue
        D = []; return;
        error('polyhedron is empty'); 
    end;
    
    % norm facets and store
    n = sqrt( sum(H.*H, 2) );           % vector of 2-norms
    Hi{end+1} = H .* repmat(1./n, 1, dim);
    Ki{end+1} = K ./ n;
end;

% get preliminary markings
M = getPrelimM(Hyp, Hi, Ki, tol, Opt);

% NOTE: 
% We do not need to extend the hyperplanes in HypInit.
% Thus we consider only the hyperplanes in the rest, but need to then shift
% the whole groups.

% group hyperplanes that are in the rest
%Hgroup = groupHyper(HypRest, tol, Opt);
Hgroup = groupHyper(Hyp, tol, Opt);

% % shift the hyperplane group by the total number of initial hyperplanes
% for i = 1:length(Hgroup)
%     Hgroup{i} = Hgroup{i} + length(HypInit.A);
% end;

% extend hyperplanes
M = extendHyper(M, Hyp, Hgroup, dom, tol, Opt);

% check: any unresolved hyperplanes (any 0 in M)?
if find(M==0),
    error('unresolved hyperplanes in the set of markings M')
end;

% change back to the sign convention of the file (in contrast to Ziegler)
D = (-1)*M;

return






% -------------------------------------------------------------------------

% get preliminary markings
function M = getPrelimM(Hyp, Hi, Ki, tol, Opt);

if Opt.verbose, 
    fprintf('  get preliminary markings\n');
end;

% Go through all hyperplanes of the hyperplane arrangment Hyp and determine 
% the relative position of each polyhedron with respect to that hyperplane 
% (cuts, on - or on + side, a facets / no facets). This matrix M has as many 
% rows as hyperplanes and as many columns as polyhedra. As we increase the 
% number of polyhedra later, also M will be increased (with additional 
% columns). The entries have the following meaning: 
%	-1:   polyhedron is on the - side of the hyperplane; 
%         the hyperplane is a facet of the polyhedron
%	-0.5: polyhedron is on the - side of the hyperplane;
%         the hyperplane is redundant
%	0:    polyhedron is cut by the hyperplane
%	+0.5: polyhedron is on the + side of the hyperplane;
%         the hyperplane is redundant
%	+1:   polyhedron is on the + side of the hyperplane;
%         the hyperplane is a facet of the polyhedron
% example: M(4,:) = [-1 0 0 1 1 0.5]: 
%      We have 6 polyhedra. The hyperplane #4 cuts the polyhedra #2 and #3.
%      The polyhedron #1 is on the - side of the 4-th hyperplane, the 
%      polyhedra #4, #5 and #6 are on the + side. The 4-th hyperplane is a
%      facet of the polyhedra #1, #4 and #5.
% Thus, if M doesn't contain any 0 element, we have already the markings.

if Opt.verbose==2
    fprintf('  derive markings of hyperplane #i / %i:\n ', length(Hyp.B));
end;

% go through all hyperplanes
M = NaN*ones(length(Hyp.B), length(Ki));
for i=1:length(Hyp.B)
    
    if Opt.verbose==2, fprintf(' #%i', i); end;
    
    % consider the i-th hyperplane a*x = b
    a = Hyp.A(i,:);
    b = Hyp.B(i);
    
    % go through all polyhedra
    for p = 1:length(Ki)
        % is the i-th hyperplane a facet of the p-th polyhedron?
        % all facets and hyperplanes are normed. 
        % thus, we can simply compare them ...
        H = repmat([Hyp.A(i,:) Hyp.B(i)], length(Ki{p}), 1);
        sameInd = find(sum(abs([Hi{p} Ki{p}] - H), 2) < tol.coeff);
        oppoInd = find(sum(abs([Hi{p} Ki{p}] + H), 2) < tol.coeff);
        if length(sameInd) > 1, warning('polyhedron has redundant facets'), end;
        if length(oppoInd) > 1, warning('polyhedron has redundant facets'), end;
        same = 0;
        if sameInd
            % the facet with index 'sameInd' is the same as the i-th
            % hyperplane
            same = 1;
        end
        if oppoInd
            % the facet with index 'oppoInd' is the opposite of the i-th
            % hyperplane
            same = -1;
        end
        if sameInd & oppoInd, error('facet can not point in two directions'); end;

        if same
            % yes, it is
            % --> add the position of the polyhedron to Hpos
            M(i,p) = (-1)*same;      % -1, +1 (non-redundant)
        else
            % no, it is not
            % --> get position of polyhedron relative to the hyperplane
            m = mpt_intersectHP1(Hi{p}, Ki{p}, a, b, Opt.lpsolver, tol.intersect);
            M(i,p) = m*0.5;          % -0.5, 0, +0.5 (redundant or cut)
        end;
        
    end;
end;

return




% -------------------------------------------------------------------------

% group hyperplanes
function Hgroup = groupHyper(Hyp, tol, Opt);


% Find groups of parallel hyperplanes. Each group contains a sorted index 
% list of hyperplanes (sorted means, that the b is increasing).
% --> Hgroup
% ex.: Hgroup{3} = [4 2 3]: the group #3 contains the hyperplanes 2, 3 and
%      4 which are sorted with respect to their b's.

if Opt.verbose, 
    fprintf('  group hyperplanes\n');
end;

% index of hyperplanes that are not grouped yet
notGrouped = 1:length(Hyp.B);

Hgroup = [];
while notGrouped
    
    % get the first not yet grouped hyperplane: a*x = b
    a = Hyp.A(notGrouped(1),:);
    b = Hyp.B(notGrouped(1));
    
    % find indices (corresponding to the hyperplanes in notGrouped) of all 
    % hyperplanes in notGrouped that are parallel to a*x = b 
    % (including a*x = b)
    paraInd = notGrouped(all( abs(repmat(a,length(notGrouped),1)-Hyp.A(notGrouped,:)) < tol.coeff, 2));
    
    % get the b's of the corresponding hyperplanes
    paraB = Hyp.B(paraInd);
    
    % sort them
    [paraBsorted, paraIndSortedInd] = sort(paraB);
    paraInd = paraInd(paraIndSortedInd);
    
    % check hyperplane arrangement (are there duplicates = same b?)
    if Opt.safeMode
        for i=1:length(paraBsorted)-1
            if abs(paraBsorted(i)-paraBsorted(i+1)) <= tol.coeff, 
                if Opt.verbose>0,
                    fprintf('  found duplicate hyperplane in group %i:\n', length(Hgroup)+1); 
                end
                paraInd
                pause
            end;
        end;
    end;
    
    % these hyperplanes form a new group
    Hgroup{end+1} = paraInd;
    
    % update notGrouped
    for i=paraInd
        notGrouped(notGrouped==i) = [];
    end;
    
end;

if Opt.verbose>0,
    fprintf('  ==> found %i different groups of parallel hyperplanes\n', length(Hgroup))
end
if Opt.verbose == 3
    % show all groups
    for i=1:length(Hgroup)
        fprintf('      %i-th group: ', i);
        fprintf('%i ', Hgroup{i});
        fprintf('\n');
    end;
end;

return



% -------------------------------------------------------------------------

% extend hyperplanes
function M = extendHyper(M, Hyp, Hgroup, dom, tol, Opt);

if Opt.verbose, 
    fprintf('  extend hyperplanes\n ');
end;

% Go through all groups.
% Go through all hyperplanes of the group (in ascending order, thus b is
% also ascending).
% Go through all polyhedra that are cut by the hyperplane.
% Cut the polyhedron P into two: P+, P-. Create a new polyhedron for the 
% minus side of the hyperplane. Thus, P- is never cut by any hyperplane of 
% the group (don't update anything for the group).
% Check for P+ and P- if there are some hyperplanes that turn out to be now 
% redundant.
% If we have for P- any zero-markings of hyperplanes that are in 
% hGroupIndices (unresolved hyperplanes in the current group), set these 
% markings to -0.5.
% Which hyperplanes except of the ones in hGroupIndices cut P?
% Are they also cutting the new polyhedra P+ and P-? Update M. If the
% hyperplane is not cutting, it is redundant. Why?
% If it was non-redundant, it would be a facet. But this we have
% determined in the very beginning of the algorithm. There, we have
% concluded, that the i-th hyperplane is not a facet but that it is
% cutting through.

% For large M with many rows, most of the time is needed to add a new row.
% Thus, we allocate always a large number of rows at once (e.g. 1000 rows).
% We store the current length of M (the number of rows that refer to
% polyhedra) by Mlen. Last, we remove the rows not needed.

if Opt.verbose==2, fprintf('  extend hyperplanes of group #i / %i:\n ', length(Hgroup)); end;

Mlen = size(M, 2);  % length of M

for g=1:length(Hgroup)

    if Opt.verbose==2, fprintf(' #%i', g); end;

    % go through all hyperplanes of the group
    for i=1:length(Hgroup{g})
        
        % consider the i-th hyperplane h.a*x = h.b
        h.i = Hgroup{g}(i);
        h.a = Hyp.A(h.i,:);
        h.b = Hyp.B(h.i);
            
        if Opt.verbose==3, fprintf('  hyperplane #%i: [', h.i); fprintf(' %1.2f', h.a); fprintf(' ] = %1.2f\n', h.b); end;
     
        % find the polyhedra which are cut by h.a*x = h.b
        % these are the ones which have a 0-entry in M
        % --> pCutIndices
        pCutIndices = find( M(h.i,1:Mlen)==0 );
        
        if Opt.verbose==3, disp(' '); fprintf('    region(s) which are cut by this hyperplane:'); fprintf(' %i;', pCutIndices); fprintf('\n'); end;
        
        % go through all polyhedra that are cut by the i-th hyperplane
        j = 1;
        while j <= length(pCutIndices)
            % we are looking at the p-th hyperplane
            p = pCutIndices(j);
            
            % which hyperplanes of our group are left?
            hGroupIndices = Hgroup{g}(i+1:length(Hgroup{g}));
                       
            % cut polyhedron
            [M, Mlen, remR] = cutPolyhedron(M, Mlen, Hyp, p, h, hGroupIndices, dom, Opt, tol);
            
            if remR
                % we have removed the r-th (old) polyhedron
                % --> update pCutIndices and reset the counter
                pCutIndices = find( M(h.i,1:Mlen)==0 );
                j = 1;
            else 
                j = j+1;
            end;
            
        end;
        
    end;
end;  
M = M(:,1:Mlen);

% round to -1, -0.5, 0, 0.5, 1 (to avoid numerical problems later)
M = round(M*2)/2;

return




% ----------------------------------------------------------------------

function [M, Mlen, remR] = cutPolyhedron(M, Mlen, Hyp, r, h, hGroupIndices, dom, Opt, tol);

% inputs:
% Mlen = length of M, number of regions in M
% r = number of region that is cut
% h.a*x = h.b: hyperplane
% h.i: index of this hyperplane
% hCutIndices: indices of hyperplanes that also cut region #r

% we know a priori, that a*x = b intersects with the r-th polyhedron
% check this
if Opt.safeMode
    
    % build the r-th polyhedron
    % based on the markings and restrict the polyhedron to the domain
    % use only facets (entries with -1, +1)
    facetInd = find( abs(M(:,r))>0.75 );
    H = [(-1)*diag(M(facetInd,r)) * Hyp.A(facetInd,:); dom.A];
    K = [(-1)*diag(M(facetInd,r)) * Hyp.B(facetInd)  ; dom.B];
    
    m = mpt_intersectHP1(H, K, h.a, h.b, Opt.lpsolver, tol.intersect);
    if m
        % no intersection
        %warning('hyperplane does not intersect with the region')
        %M(h.i,r) = m;
        %return;
        error('hyperplane does not intersect with the region')
    end;
end;

% index of new polyhedron
Mlen = Mlen + 1;
s = Mlen; 

if Opt.verbose==3, fprintf('    ... region #%i is split into regions #%i and #%i\n', r,r,s); end;

% if we have no new row allocated already, allocate another 1000 rows
% we do this to reduce memory allocation time
if size(M,2) < Mlen
    M = [M NaN*ones(size(M,1), 1000)];
    if Opt.verbose==3, disp('allocated another 1000 rows for M'); end;
end;

% set the markings
M(:,s)   = M(:,r);
M(h.i,r) = +1;
M(h.i,s) = -1;  % the new polyhedron (the s-th) lies on the - side of a*x=b

% index of non-redundant facets (markings == +/- 1)
facetInd = find( abs(M(:,r))>0.75 );

% build the r-th polyhedron
% based on the markings and restrict the polyhedron to the domain
Hr = [(-1)*diag(M(facetInd,r)) * Hyp.A(facetInd,:); dom.A];
Kr = [(-1)*diag(M(facetInd,r)) * Hyp.B(facetInd)  ; dom.B];

% and accordingly the s-th polyhedron:
Hs = [(-1)*diag(M(facetInd,s)) * Hyp.A(facetInd,:); dom.A];
Ks = [(-1)*diag(M(facetInd,s)) * Hyp.B(facetInd)  ; dom.B];


% Check for r and s if there are some hyperplanes that turn out to be now 
% redundant (in exHyper1 and exHyper2, this was done by determining the 
% unresolved hyperplanes and by distributing them).

% for the r-th polyhedron:
candrows = 1:length(facetInd);
[Hr_red,Kr_red,r_empty,keptrows] = tg_polyreduce(Hr, Kr,tol.polyreduce,Opt.lpsolver,1,candrows);
if r_empty, 
    %if Opt.verbose, disp('cutPolyhedron: r-th polyhedron is empty -- remove'); end;
else
    keptrows_r = keptrows(keptrows<=candrows(end));
    candrows(keptrows_r) = [];
    remrows = facetInd(candrows);   % these rows have been removed, 
                                    % thus these hyperplanes are redundant
    M(remrows,r) = 0.5*M(remrows,r);
end;

% for the s-th polyhedron:
candrows = 1:length(facetInd);
[Hs_red,Ks_red,s_empty,keptrows] = tg_polyreduce(Hs, Ks,tol.polyreduce,Opt.lpsolver,1,candrows);
if s_empty, 
    %if Opt.verbose, disp('cutPolyhedron: s-th polyhedron is empty -- remove'); end; 
else
    keptrows_s = keptrows(keptrows<=candrows(end));
    candrows(keptrows_s) = [];
    remrows = facetInd(candrows);   % these rows have been removed, 
                                    % thus these hyperplanes are redundant
    M(remrows,s) = 0.5*M(remrows,s);
end;

% If we have for the s-th polyhedron any zero-markings for hyperplanes that
% are in hGroupIndices (unresolved hyperplanes in the current group), 
% we set these markings to -0.5.
% Why? Because we know, that these hyperplanes are parallel to the i-th we
% are dealing with and because they are further away from the origin. Keep
% in mind, that the normal vectors of the hyperplanes are all pointing in
% x1-direction.
ind = hGroupIndices( M(hGroupIndices,s)==0 );
M(ind,s) = -0.5;


% Are any hyperplanes except of the ones in hGroupIndices cutting the 
% polyhedron (#r or #s, that doesn't matter)? 
% This we can learn by looking at the zero-entries in M.
hNotGroupIndices = 1:length(Hyp.B);
hNotGroupIndices(hGroupIndices) = [];
hCutIndices = hNotGroupIndices( M(hNotGroupIndices,r)==0 );



% so the hyperplanes with indices hCutIndices cut our old polyhedron.
% are they also cutting the new polyhedra #r and #s?
% check this and update M accordingly. 
if hCutIndices
    % get position of polyhedra #r and #s relative to the hyperplanes
    for i=hCutIndices(:)'
        
        % for polyhedron #r
        if ~r_empty
            M(i,r) = 0.5*mpt_intersectHP1(Hr_red, Kr_red, Hyp.A(i,:), Hyp.B(i), Opt.lpsolver, tol.intersect);
        end;
        
        % for polyhedron #s
        if ~s_empty
            M(i,s) = 0.5*mpt_intersectHP1(Hs_red, Ks_red, Hyp.A(i,:), Hyp.B(i), Opt.lpsolver, tol.intersect);
        end;
        
        % remark:
        % the i-th hyperplane is either cutting through or it is redundant.
        % If it was non-redundant, it would be a facet. But this we have
        % determined in the very beginning of the algorithm. There, we have
        % concluded, that the i-th hyperplane is not a facet but that it is
        % cutting through.
        
        % remark:
        % we check the position of the polyhedra only if they are not empty
        % Empty polyhedra will we be removed in any case in a next step and
        % would cause the function intersectHP to terminate with an error.
    end;
end;

if Opt.safeMode
    % check whether the two new polyhedra are feasible
    if r_empty, mr = []; else mr = M(:,r); end;
    if s_empty, ms = []; else ms = M(:,s); end;
    checkPoly(fix([mr ms]), Hyp, dom, Opt);  % look only at -1, 1
    checkPoly(round([mr ms]), Hyp, dom, Opt);  % look at -1, -0.5, 0.5, 1
end;

if r_empty
    % remove the r-th polyhedron
    M(:,r) = [];    
    Mlen = Mlen - 1;
    
    s = s-1;
    remR = 1;
else
    % we have updated the polyhedron already
    remR = 0;
end;

if s_empty
    % remove the s-th polyhedron
    M(:,s) = [];
    Mlen = Mlen - 1;
end;




% ----------------------------------------------------------------------

function [negInd, r_min] = checkPoly(M, Hyp, dom, Opt)
% check the size of the polyhedra with the markings M in the HA Hyp.
% in negInd, we give back the indices of the polyhedra with negative radius
% of Chebycheff ball.
% in r_min, we give back the smallest radius

% minimal radius of Chebycheff ball of a polyhedron
r_warn = 1e-6; 

r_min = inf;
negInd = [];

for i = 1:size(M,2)
    
    % build polyhedron  
    facetInd = find( abs(M(:,i)) > 0.75 );
    H = [(-1)*diag(M(facetInd,i)) * Hyp.A(facetInd,:); dom.A];
    K = [(-1)*diag(M(facetInd,i)) * Hyp.B(facetInd)  ; dom.B];
       
    % Chebycheff ball in polyhedron
    [x, r] = polyinnerball(H, K);
    %if Opt.verbose==2, fprintf('  polyhedron #%i: R=%1.4f\n', i, r); end;
    if r <= 0, 
        % polyhedron is empty
        if Opt.verbose>0,
            disp('warning: polyhedron is empty'); 
        end
        negInd(end+1) = i;
    elseif r < r_warn, 
        % radius is below threshold
        if Opt.verbose>0,
            fprintf('warning: Chebycheff radius of %i-th polyhedron is less than 1e-6: r=%1.4e\n', i, r), 
        end
    end;
    
    if r < r_min, r_min = r; end;
    
end;















% --------------------------------------------------------------------
% --------------------------------------------------------------------

function delta = lp_hyparr_old(A,B,H,K)
delta = [];
nx = size(A,2);
na = size(H,1);
nc = size(A,1);
wc = 2^nc;      % argh: go through all the combinations
for i = 0:wc-1,
    reg = + ones(nc,1) - 2*(dec2bin(i,nc)-'0')';    % derive the i-th marking
    
    %if is_feasible([diag(reg)*A;H],[diag(reg)*B;K]),% check whether the corresponding region is feasible
    %    delta = [delta, reg];
    
    % get the center x and the radius r of the polyhedron
    % solver: 0=NAG, 1=linprog, 2=cplex
    [x,r] = polyinnerball([diag(reg)*A;H],[diag(reg)*B;K], 0);
    if r > 0, delta = [delta, reg]; end
end




% --------------------------------------------------------------------

function delta = kf_hyparr(A,B,H,K)

% add the bounding constraints H, K
AA = [[A;H],-[B;K];[zeros(1,size(A,2)),1]];

% to avoid numerical problems
ind = find(abs(AA)<1e-10);
AA(ind) = 0;

% Play the dirty trick (rs_alltope accepts only integers)
m = min(abs(AA(find(AA)))); 
M = max(abs(AA(find(AA)))); 
% AA = round(1e5 * AA / m);
maxInt = 15500;
AA = round(maxInt/M * AA);

% regularize the matrix 
% 1. find the zero columns
zerocols = all(AA == 0,1);

% 2. find the repeated columns
nc = size(AA,1);
redrows = zeros(nc,1);
for i = 1:size(AA,1),
    for j = i+1:size(AA,1),
        if AA(i,:) == AA(j,:)
            redrows(j,1) = i; % store that row j = row i
        end
    end
end

% get markings
delta_tmp = zonotope(AA(find(redrows == 0),find(~zerocols)));
delta(find(redrows == 0),:) = delta_tmp;

% add back the rows that were removed
for i = 1:size(AA,1)
    if redrows(i,1) ~= 0,
        delta(i,:)=delta(redrows(i,1),:);
    end
end

% consider the lifted hyperplane arrangement should have '-1' in the last constraint
% therefore remove the entries with 1
delta(:,find(delta(end, :) == 1)) = [];

% remove the last line containing the added constraint
delta(end,:) = [];

% Consider only the regions that satisfy H and K
% therefore remove the entries with -1
for i = (size(A, 1) + 1):(size(A, 1) + size(H, 1))
    delta(:, find(delta(i, :) == -1)) = [];
end

% remove the markings corresponding to the bounding constraints
delta(end-length(K)+1:end,:)=[];


















function delta = hyparr_test(Hyp, P, dom, verbose, choice)

% there are two ways of computing that:
% 1. Checking all the possibilities
% 2. Using the tool from Komei Fukuda <http://www.cs.mcgill.ca/~fukuda/download/mink/>
% the variable choice decides which approach to use.

% Make sure, that there is not the same constraint twice

lpsolver = 0;

% choice"  
% -1: compare both methods
%     meaning of the output: computation time for method 0,
%                            computation time for method 1
%                            - if the results differ, else +
%  0: enumerate all combinations 
%     = no numerical problems, fast for small problems
%  1: use reverse search 
%     = possibly numerical problems, fast for large problems

if choice == -1
    fprintf('compare both hyperplane arrangements: ')
    
    % enumerate all combinations:
    t0 = clock;
    minR = 1e-10;
    %D_lp = lp_hyparr(Hyp,P,dom,verbose);
    D_lp = iter_lp(Hyp.A, Hyp.B, P.H, P.K, lpsolver, minR);
    %D_lp = std_lp(Hyp.A, Hyp.B, P.H, P.K, lpsolver, 0);
    fprintf('%0.2fs  ', etime(clock, t0));
    
    % plot solution
    color.Table{1} = [1:size(D_lp,2)];
    GL.Hi = Hyp.A; GL.Ki = Hyp.B;
    plotPolyMark((-1)*D_lp, color, GL, dom);
    
    % use reverse search:
    t0 = clock;
    D_kf = kf_hyparr(Hyp.A, Hyp.B, P.H, P.K);
    %D_kf = eff_hyparr(Hyp,P,dom,verbose);
    fprintf('%0.2fs  ', etime(clock, t0));

    % plot solution
    color.Table{1} = [1:size(D_kf,2)];
    GL.Hi = Hyp.A; GL.Ki = Hyp.B;
    plotPolyMark((-1)*D_kf, color, GL, dom);
    
    
    delta = D_lp;
      
    % are both markings the same?
    
    % i) do they have the same dimensions?
    if ~all(size(D_lp) == size(D_kf))
        fprintf('-\n')
        return
    end;
    
    % ii) reorder both markings such that in the first columns are the rows
    %     with most -1 entries using something like bubble sort
    if reorder(D_lp) == reorder(D_kf)
        fprintf('+\n')
    else
        fprintf('-\n')
    end;

elseif choice == 0
    
    %fprintf('\n')
    %nd = length(B);
    %fprintf('get hyperplane arrangements (by enumeration) of %1i d-variables ... ', nd)
    
    %t0 = clock;
    delta = lp_hyparr(A,B,H,K,dom,verbose);
    %fprintf(' %0.2fs\n', etime(clock, t0));
    
elseif choice == 1
    
    delta = kf_hyparr(A,B,H,K);
    
else
    
    error('unkown choice in hyparr')
    
end


% --------------------------------------------------------------------

function D = reorder(D)

expo = []; for i=0:size(D,1)-1, expo(end+1) = 2^i; end; expo=expo';
E = kron( ones(1,size(D,2)), expo );
[dummy, sortedIndices] = sort( sum(D.*E,1) );
D = D(:,sortedIndices);



% --------------------------------------------------------------------

% Buck's formula
n = 100;    % # hyperplanes
d = 3;      % dimension
N = 0;
for i=1:d
    N = N + nchoosek(n,i);
end;
