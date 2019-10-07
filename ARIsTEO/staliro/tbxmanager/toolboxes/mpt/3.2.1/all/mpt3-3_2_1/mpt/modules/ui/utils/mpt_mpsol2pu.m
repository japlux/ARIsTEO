% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
function pu = mpt_mpsol2pu(sol)
%
% converts solution generated by YALMIP's solvemp() to MPT's PolyUnion
%

if ~iscell(sol)
	sol = {sol};
end
if isempty(sol{1})
	pu = PolyUnion;
else	
	pu = [];
	for i = 1:numel(sol)
        P = toPolyhedron(sol{i}.Pn);
		for j = 1:length(sol{i}.Pn)
			% add functions to mimic the output of Opt.solve:
			%     'z'    'w'    'primal'    'dual'    'obj'
			P(j).addFunction(AffFunction(0*sol{i}.Fi{j}, 0*sol{i}.Gi{j}), 'z');
			P(j).addFunction(AffFunction(0*sol{i}.Fi{j}, 0*sol{i}.Gi{j}), 'w');
			P(j).addFunction(AffFunction(sol{i}.Fi{j}, sol{i}.Gi{j}), 'primal');
			P(j).addFunction(AffFunction(0*sol{i}.Fi{j}, 0*sol{i}.Gi{j}), 'dual');
			if isempty(sol{i}.Ai{j})
				% affine expression for the cost
				P(j).addFunction(AffFunction(sol{i}.Bi{j}, sol{i}.Ci{j}), 'obj');
			else
				% quadratic expression for the cost
				P(j).addFunction(QuadFunction(sol{i}.Ai{j}, sol{i}.Bi{j}, ...
					sol{i}.Ci{j}), 'obj');
			end
		end
		new = PolyUnion('Set', P, 'Bounded', true, 'FullDim', true, ...
            'Overlaps', sol{i}.overlaps, ...
			'Convex', sol{i}.convex, 'Domain', toPolyhedron(sol{i}.Pfinal));
		pu = [pu, new];
		
	end
end
