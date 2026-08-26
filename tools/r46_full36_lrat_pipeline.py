#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, itertools, json, math
from collections import Counter
from pathlib import Path
import networkx as nx

R36_17_SHA256='3286c5366ddc70f349c3f7e798d7acbc79dc026c7abe0c8f406cad41ca990361'
EXPECTED_ROOT_PLAIN_SHA256='a9210d8ab43fa25877da15c6279e96d93f8433289b50798981a24156e4003cb9'
EXPECTED_ROOT_VARS=14076
EXPECTED_ROOT_CLAUSES=593350
EXPECTED_STRUCTURAL_CLAUSES=540648
CUBE_ASSUMPTIONS=list(range(1,14))

def sha256_file(p:Path)->str:
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1<<20),b''): h.update(b)
    return h.hexdigest()

def graph_from_g6(line:str)->nx.Graph:
    g=nx.from_graph6_bytes(line.strip().encode('ascii'))
    return nx.convert_node_labels_to_integers(g,ordering='sorted')

def is_clique(g,s): return all(g.has_edge(a,b) for a,b in itertools.combinations(s,2))
def is_independent(g,s): return all(not g.has_edge(a,b) for a,b in itertools.combinations(s,2))
def subsets(g,k,independent):
    pred=is_independent if independent else is_clique
    return [s for s in itertools.combinations(range(g.number_of_nodes()),k) if pred(g,s)]

def make_vm(d,m):
    nxt=1; x={}
    for i in range(d):
        for a in range(m): x[(i,a)]=nxt; nxt+=1
    y={}
    for a,b in itertools.combinations(range(m),2): y[(a,b)]=nxt; nxt+=1
    assert nxt-1==d*m+math.comb(m,2)
    return x,y,nxt-1

def yvar(y,a,b):
    if a>b:a,b=b,a
    return y[(a,b)]

def build_n00_root(g6_path:Path, out_dir:Path):
    assert sha256_file(g6_path)==R36_17_SHA256
    lines=[x.strip() for x in g6_path.read_text().splitlines() if x.strip()]
    assert len(lines)==7
    N=graph_from_g6(lines[0]); d=17; m=18; min_degree=11
    assert N.number_of_nodes()==d and not subsets(N,3,False) and not subsets(N,6,True)
    x,y,primary=make_vm(d,m)
    C=[]; hist=Counter()
    def add(kind,lits):
        t=tuple(lits); assert t; C.append(t); hist[kind]+=1
    for J in itertools.combinations(range(m),4): add('K4_0N4M',(-yvar(y,a,b) for a,b in itertools.combinations(J,2)))
    for J in itertools.combinations(range(m),5): add('I6_v0N5M',(yvar(y,a,b) for a,b in itertools.combinations(J,2)))
    n_edges=list(N.edges())
    n_nonedges=[p for p in itertools.combinations(range(d),2) if not N.has_edge(*p)]
    i3=subsets(N,3,True); i4=subsets(N,4,True); i5=subsets(N,5,True)
    for i in range(d):
        for J in itertools.combinations(range(m),3): add('K4_1N3M',[-x[(i,a)] for a in J]+[-yvar(y,a,b) for a,b in itertools.combinations(J,2)])
    for i,j in n_edges:
        for a,b in itertools.combinations(range(m),2): add('K4_2N2M',(-x[(i,a)],-x[(i,b)],-x[(j,a)],-x[(j,b)],-yvar(y,a,b)))
    for I in i5:
        for a in range(m): add('I6_5N1M',(x[(i,a)] for i in I))
    for I in i4:
        for a,b in itertools.combinations(range(m),2): add('I6_4N2M',[x[(i,z)] for i in I for z in (a,b)]+[yvar(y,a,b)])
    for I in i3:
        for J in itertools.combinations(range(m),3): add('I6_3N3M',[x[(i,a)] for i in I for a in J]+[yvar(y,a,b) for a,b in itertools.combinations(J,2)])
    for i,j in n_nonedges:
        for J in itertools.combinations(range(m),4): add('I6_2N4M',[x[(p,a)] for p in (i,j) for a in J]+[yvar(y,a,b) for a,b in itertools.combinations(J,2)])
    assert len(C)==EXPECTED_STRUCTURAL_CLAUSES
    bounds=[]
    for i in range(d):
        bounds.append({'id':f'N[{i}]','literals':[x[(i,a)] for a in range(m)],'lower':min_degree-1-N.degree(i),'upper':d-1-N.degree(i)})
    for a in range(m):
        bounds.append({'id':f'M[{a}]','literals':[x[(i,a)] for i in range(d)]+[yvar(y,a,b) for b in range(m) if b!=a],'lower':min_degree,'upper':d})
    ext=[]; rows=[]; nxt=primary+1
    for r in bounds:
        xs=list(r['literals']); n=len(xs); t={}; start=nxt
        for i in range(1,n+1):
            for j in range(1,i+1): t[(i,j)]=nxt; nxt+=1
        z=t[(1,1)]; xx=xs[0]; ext.extend([(-z,xx),(z,-xx)])
        for i in range(2,n+1):
            xx=xs[i-1]; z=t[(i,1)]; a=t[(i-1,1)]; ext.extend([(-a,z),(-xx,z),(-z,a,xx)])
            for j in range(2,i):
                z=t[(i,j)]; a=t[(i-1,j)]; b=t[(i-1,j-1)]
                ext.extend([(-a,z),(-b,-xx,z),(-z,a,b),(-z,a,xx)])
            z=t[(i,i)]; b=t[(i-1,i-1)]; ext.extend([(-z,b),(-z,xx),(z,-b,-xx)])
        L=int(r['lower']); U=int(r['upper'])
        if L>0: ext.append((t[(n,L)],))
        if U<n: ext.append((-t[(n,U+1)],))
        rows.append({'id':r['id'],'input_variables':xs,'n':n,'lower':L,'upper':U,'aux_start':start,'aux_end':nxt-1,'threshold_final':{str(j):t[(n,j)] for j in range(1,n+1)}})
    allc=C+ext; nvars=nxt-1
    assert nvars==EXPECTED_ROOT_VARS and len(allc)==EXPECTED_ROOT_CLAUSES
    out_dir.mkdir(parents=True,exist_ok=True)
    root=out_dir/'FULL36_D17_N00.proof.cnf'
    h=hashlib.sha256()
    with root.open('wb') as f:
        def emit(s):
            b=s.encode('ascii'); h.update(b); f.write(b)
        emit('c r46-rooted-one-sided-v2 proof-root threshold-dp\n')
        emit(f'c total_vertices=36 primary_variables={primary}\n')
        emit(f'p cnf {nvars} {len(allc)}\n')
        for c in allc: emit(' '.join(map(str,c))+' 0\n')
    assert h.hexdigest()==EXPECTED_ROOT_PLAIN_SHA256
    cube=out_dir/'FULL36_D17_N00_N0_UPPER12_VIOLATION_CUBE.cnf'
    with root.open('rt',encoding='ascii') as src, cube.open('wt',encoding='ascii',newline='\n') as dst:
        replaced=False
        for line in src:
            if line.startswith('p cnf '):
                parts=line.split(); assert int(parts[2])==nvars and int(parts[3])==len(allc)
                dst.write(f'p cnf {nvars} {len(allc)+len(CUBE_ASSUMPTIONS)}\n'); replaced=True
            else: dst.write(line)
        assert replaced
        for lit in CUBE_ASSUMPTIONS: dst.write(f'{lit} 0\n')
    meta={
      'schema':'r46-full36-lrat-pipeline-v1','root_id':'FULL36_D17_N00','catalog_graph6':lines[0],
      'root_variables':nvars,'root_clauses':len(allc),'root_sha256':sha256_file(root),
      'cube_variables':nvars,'cube_clauses':len(allc)+len(CUBE_ASSUMPTIONS),'cube_sha256':sha256_file(cube),
      'cube_assumptions':CUBE_ASSUMPTIONS,
      'cube_semantics':'Set x[N0,M0..M12]=1. N[0] has exact cross-edge upper bound 12, so the 13th true edge violates the threshold-DP bound.',
      'degree_row_N0':rows[0],'expected_root_sha256':EXPECTED_ROOT_PLAIN_SHA256,
      'structural_clauses':len(C),'degree_encoding_clauses':len(ext)
    }
    (out_dir/'cube_metadata.json').write_text(json.dumps(meta,indent=2,sort_keys=True)+'\n')
    return meta

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--g6',type=Path,required=True); ap.add_argument('--out',type=Path,required=True)
    a=ap.parse_args(); print(json.dumps(build_n00_root(a.g6,a.out),sort_keys=True))
if __name__=='__main__': main()
