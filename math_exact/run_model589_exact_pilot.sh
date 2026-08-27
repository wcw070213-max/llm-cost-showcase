#!/usr/bin/env bash
set -euo pipefail

SCIP_URL='https://github.com/scipopt/scip/releases/download/v10.0.3/scipoptsuite-10.0.3-glibc2_28-amd64.tgz'
SCIP_TGZ_SHA256='ddbb7129bdb83f8f70ed26391d206fd1658139e44c7c7fd7d73a1e4cefbca94f'
VIPR_COMMIT='30f2951d1e90e47afa821bdd1b12b82246656c42'

mkdir -p exact_models exact_results

cat > chunks_352.sha256 <<'EOF'
2817a9c6aaf3d55002fe0fbfc22ba4b430556793b3f577223b70ffdcff924ef4  math_exact/models/chunks/model_352.part00
ef49abe0d3155162dcd0e70c71b1eb0b743a5d65d0ee7e90df0da159e0c20283  math_exact/models/chunks/model_352.part01
3ba870ef4160a397602c5fd6b7257b1d891d1e01f9770a58cd7274f7d1cfa53e  math_exact/models/chunks/model_352.part02
f8c3c8ab7f8db54173f22894cb0c4010f48a68ae0dbeabb14ae87a8914caae3c  math_exact/models/chunks/model_352.part03
28e5f5d4048992364474c362ef2917c0c3e78d4d87ff3f5d4d89eb0690b2c0bf  math_exact/models/chunks/model_352.part04
2674787a21e20fe66743ec23f83113a28a3ec9b53f413d02649fc61f696752c7  math_exact/models/chunks/model_352.part05
d5a0d04fc171ff3772918b6c0e144d56de65f315f1e97ab83352153ed4151e5b  math_exact/models/chunks/model_352.part06
445a273fcf08fbc97808cd647dfb6fd4101e5b90113454470c35de8471373294  math_exact/models/chunks/model_352.part07
EOF
cat > chunks_589.sha256 <<'EOF'
b9d876d9a6b9b6e94f896fe22684481ab969884842123118f442b1d681edda2b  math_exact/models/chunks/model_589.part00
421d6814ce2c013d4d9a882cf514fe2021c703d1a5b472ed5dbc995b2f5d5a98  math_exact/models/chunks/model_589.part01
abf46699bbdc9cdbb91b5ce583a3ebf850a3e507451d0fc8dbc323c6c4811597  math_exact/models/chunks/model_589.part02
d7baebae0ca7ed3ff9e9306ca1a66703df430e0bfb3a3eb0f24edd2875cff871  math_exact/models/chunks/model_589.part03
220c62a408d191b58e8438ca49fd59f7576c15e2cacf3a720deed94b30bbaddc  math_exact/models/chunks/model_589.part04
c0494c2f7d84895363608d6757ab369582e533c9856c22217cc1aee4cbe9ffce  math_exact/models/chunks/model_589.part05
044d5b8ed6dd3b5961cdecfd3123842b0fb7a7eb931b46777435efb170648822  math_exact/models/chunks/model_589.part06
8d833ae9fd5ca0c37d18ec450ffd7679158993083aa1b31477d7581a2e7841bf  math_exact/models/chunks/model_589.part07
EOF
sha256sum -c chunks_352.sha256
sha256sum -c chunks_589.sha256

reassemble() {
  local id="$1" b64sha="$2" xzsha="$3" lpsha="$4" modelsha="$5"
  cat math_exact/models/chunks/model_${id}.part* > exact_models/model_${id}.lp.xz.b64
  test "$(sha256sum exact_models/model_${id}.lp.xz.b64 | cut -d' ' -f1)" = "$b64sha"
  base64 -d exact_models/model_${id}.lp.xz.b64 > exact_models/model_${id}.lp.xz
  test "$(sha256sum exact_models/model_${id}.lp.xz | cut -d' ' -f1)" = "$xzsha"
  xz -t exact_models/model_${id}.lp.xz
  xz -dc exact_models/model_${id}.lp.xz > exact_models/model_${id}.lp
  test "$(sha256sum exact_models/model_${id}.lp | cut -d' ' -f1)" = "$lpsha"
  grep -q "model_id=${id} profile=R5_RHO4_TAU3 model_sha256=${modelsha}" exact_models/model_${id}.lp
}
reassemble 352 af496c94d9930578e119a9e6d07c2338d2fd3b17ef37219bf4048003d09c20de e82ce3c3d1dbcfa8f1ef54e7cda3f5a3fe4a316a683774e128371af97423b019 1d549df8d1c5b46746fdaa569cf3dccbf71667211afc4a53a10bd1803e3ddb15 116f2c2dc96447c74b617285bbb0c757c8434f0f08a89dcc04ebce299f937aa3
reassemble 589 0e162cdfc5a67f68914b46354d875669944e399ea9d646f423f9651e5798cab9 e884d61f18bf02d7fdb61f4b759ff34703500e1600771eb40a6cad37d8643853 a2c5f1257a5330ed8c81837ad14a3eb204ac8c32d15e94d1b94e932c95fa18e1 d7e26cb20c2629ecd7b0b148f05977616e084951db5d19a8932855f3cd92c57b
sha256sum exact_models/* chunks_352.sha256 chunks_589.sha256 > exact_results/model_input_sha256.txt

sudo apt-get update
sudo apt-get install -y build-essential cmake ninja-build libgmp-dev zlib1g-dev

curl -L --fail --retry 3 -o scip.tgz "$SCIP_URL"
test "$(sha256sum scip.tgz | cut -d' ' -f1)" = "$SCIP_TGZ_SHA256"
tar -xzf scip.tgz
SCIP_BIN="$(find scipoptsuite-10.0.3 -type f -name scip -perm -111 | head -1)"
test -n "$SCIP_BIN"
echo "$SCIP_BIN" > scip_binary.txt
"$SCIP_BIN" -v > exact_results/scip_version.txt 2>&1 || true
"$SCIP_BIN" -c 'set exact enable TRUE' -c 'set presolving emphasis off' -c 'set separating emphasis off' -c 'set certificate filename /tmp/scip-preflight.vipr' -c quit > exact_results/scip_preflight.txt 2>&1
if grep -Eiq 'unknown parameter|invalid parameter|not a valid parameter' exact_results/scip_preflight.txt; then
  cat exact_results/scip_preflight.txt
  exit 1
fi
sha256sum "$SCIP_BIN" scip.tgz > exact_results/scip_binary_sha256.txt

git clone https://github.com/scipopt/vipr.git vipr
git -C vipr checkout "$VIPR_COMMIT"
cmake -S vipr/code -B vipr/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DVIPRCOMP=OFF
cmake --build vipr/build --target viprchk -j 2
git -C vipr rev-parse HEAD > exact_results/vipr_commit.txt
test "$(cat exact_results/vipr_commit.txt)" = "$VIPR_COMMIT"
sha256sum vipr/build/viprchk > exact_results/viprchk_sha256.txt

proof_path() {
  local id="$1"
  if test -s exact_results/model_${id}/proof.vipr; then echo exact_results/model_${id}/proof.vipr; return; fi
  if test -s exact_results/model_${id}/proof.vipr_ori; then echo exact_results/model_${id}/proof.vipr_ori; return; fi
  return 1
}
valid_infeas_proof() {
  local p="$1"
  test -s "$p" && grep -Eq '^DER [1-9][0-9]*$' "$p" && grep -q '^RTP infeas$' "$p" && ! grep -q '^RTP range -inf inf$' "$p"
}

mkdir -p exact_results/model_352
cat > exact_results/model_352/scip.set <<'EOF'
set exact enable TRUE
set presolving emphasis off
set separating emphasis off
set conflict enable FALSE
set limits time 600
set certificate filename exact_results/model_352/proof.vipr
read exact_models/model_352.lp
optimize
display statistics
quit
EOF
timeout 750 "$SCIP_BIN" -b exact_results/model_352/scip.set > exact_results/model_352/scip.stdout 2> exact_results/model_352/scip.stderr
grep -Eiq 'problem is solved \[infeasible\]|SCIP Status[[:space:]]*:[[:space:]]*problem is solved \[infeasible\]' exact_results/model_352/scip.stdout
P352="$(proof_path 352)"
valid_infeas_proof "$P352"
echo "$P352" > exact_results/model_352/proof_path.txt
vipr/build/viprchk "$P352" > exact_results/model_352/viprchk.stdout 2> exact_results/model_352/viprchk.stderr
grep -q 'Successfully verified infeasibility' exact_results/model_352/viprchk.stdout
echo CERTIFIED_UNSAT > exact_results/model_352/mathematical_status.txt
sha256sum exact_results/model_352/* > exact_results/model_352/SHA256SUMS
echo MODEL_352_ORIGINAL_EXACT_SCIP_VIPR_REGRESSION_PASS

mkdir -p exact_results/model_589
cat > exact_results/model_589/scip.set <<'EOF'
set exact enable TRUE
set presolving emphasis off
set separating emphasis off
set conflict enable FALSE
set limits time 1200
set certificate filename exact_results/model_589/proof.vipr
read exact_models/model_589.lp
optimize
write solution exact_results/model_589/solution.sol
display statistics
quit
EOF
set +e
timeout 1350 "$SCIP_BIN" -b exact_results/model_589/scip.set > exact_results/model_589/scip.stdout 2> exact_results/model_589/scip.stderr
rc=$?
set -e
echo "$rc" > exact_results/model_589/scip_returncode.txt
status=UNKNOWN_OR_TIMEOUT
if grep -Eiq 'problem is solved \[infeasible\]|SCIP Status[[:space:]]*:[[:space:]]*problem is solved \[infeasible\]' exact_results/model_589/scip.stdout; then
  if P589="$(proof_path 589)" && valid_infeas_proof "$P589"; then
    echo "$P589" > exact_results/model_589/proof_path.txt
    set +e
    vipr/build/viprchk "$P589" > exact_results/model_589/viprchk.stdout 2> exact_results/model_589/viprchk.stderr
    vrc=$?
    set -e
    echo "$vrc" > exact_results/model_589/viprchk_returncode.txt
    if test "$vrc" = 0 && grep -q 'Successfully verified infeasibility' exact_results/model_589/viprchk.stdout; then status=CERTIFIED_UNSAT; else status=PROOF_CHECK_FAILED; fi
  else
    status=PROOF_MISSING_OR_INVALID
  fi
elif grep -Eiq 'problem is solved \[optimal solution found\]|SCIP Status[[:space:]]*:[[:space:]]*problem is solved \[optimal solution found\]' exact_results/model_589/scip.stdout; then
  status=SAT_REQUIRES_SEMANTIC_REPLAY
fi
echo "$status" > exact_results/model_589/mathematical_status.txt
sha256sum exact_results/model_589/* > exact_results/model_589/SHA256SUMS
cat exact_results/model_589/mathematical_status.txt

python3 - <<'PY'
import hashlib,json,re
from pathlib import Path
def sh(p): return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
def row(mid, model_sha, lp_sha):
    d=Path(f'exact_results/model_{mid}')
    p1=d/'proof.vipr'; p2=d/'proof.vipr_ori'; p=p1 if p1.exists() else p2
    txt=p.read_text(errors='replace') if p.exists() else ''
    m=re.search(r'^DER\s+(\d+)\s*$',txt,re.M)
    return {'model_id':mid,'model_sha256':model_sha,'lp_sha256':lp_sha,'proof_file':str(p) if p.exists() else None,'proof_exists':p.exists(),'proof_sha256':sh(p),'proof_derivations':int(m.group(1)) if m else None,'proof_target_infeas':bool(re.search(r'^RTP infeas$',txt,re.M)),'proof_target_tautological':bool(re.search(r'^RTP range -inf inf$',txt,re.M)),'status':(d/'mathematical_status.txt').read_text().strip() if (d/'mathematical_status.txt').exists() else 'NOT_REACHED','checker_stdout_sha256':sh(d/'viprchk.stdout'),'solution_sha256':sh(d/'solution.sol')}
out={'schema':'rank5_exact_scip_vipr_model589_pilot_v1','presolving_disabled':True,'separation_disabled':True,'vipr_commit':Path('exact_results/vipr_commit.txt').read_text().strip(),'regression':row(352,'116f2c2dc96447c74b617285bbb0c757c8434f0f08a89dcc04ebce299f937aa3','1d549df8d1c5b46746fdaa569cf3dccbf71667211afc4a53a10bd1803e3ddb15'),'queue_pilot':row(589,'d7e26cb20c2629ecd7b0b148f05977616e084951db5d19a8932855f3cd92c57b','a2c5f1257a5330ed8c81837ad14a3eb204ac8c32d15e94d1b94e932c95fa18e1')}
Path('exact_results/summary.json').write_text(json.dumps(out,indent=2,sort_keys=True)+'\n')
PY
find exact_results -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > exact_results/SHA256SUMS
