#!/usr/bin/env bash
set -euo pipefail
VIPR_COMMIT='30f2951d1e90e47afa821bdd1b12b82246656c42'
mkdir -p replay/model_589

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
sha256sum -c chunks_589.sha256
cat math_exact/models/chunks/model_589.part* > replay/model_589/model.lp.xz.b64
test "$(sha256sum replay/model_589/model.lp.xz.b64 | cut -d' ' -f1)" = '0e162cdfc5a67f68914b46354d875669944e399ea9d646f423f9651e5798cab9'
base64 -d replay/model_589/model.lp.xz.b64 > replay/model_589/model.lp.xz
test "$(sha256sum replay/model_589/model.lp.xz | cut -d' ' -f1)" = 'e884d61f18bf02d7fdb61f4b759ff34703500e1600771eb40a6cad37d8643853'
xz -t replay/model_589/model.lp.xz
xz -dc replay/model_589/model.lp.xz > replay/model_589/model.lp
test "$(sha256sum replay/model_589/model.lp | cut -d' ' -f1)" = 'a2c5f1257a5330ed8c81837ad14a3eb204ac8c32d15e94d1b94e932c95fa18e1'
grep -q 'model_id=589 profile=R5_RHO4_TAU3 model_sha256=d7e26cb20c2629ecd7b0b148f05977616e084951db5d19a8932855f3cd92c57b' replay/model_589/model.lp

EXPECTED_PROOF_SHA="$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path('prior/summary.json').read_text())
q=d['queue_pilot']
assert q['model_id']==589
assert q['model_sha256']=='d7e26cb20c2629ecd7b0b148f05977616e084951db5d19a8932855f3cd92c57b'
assert q['lp_sha256']=='a2c5f1257a5330ed8c81837ad14a3eb204ac8c32d15e94d1b94e932c95fa18e1'
assert q['status']=='CERTIFIED_UNSAT'
assert q['proof_derivations']==803
assert q['proof_target_infeas'] is True
assert q['proof_target_tautological'] is False
assert d['presolving_disabled'] is True
assert d['separation_disabled'] is True
print(q['proof_sha256'])
PY
)"
test -n "$EXPECTED_PROOF_SHA"
test -s prior/model_589/proof.vipr
test "$(sha256sum prior/model_589/proof.vipr | cut -d' ' -f1)" = "$EXPECTED_PROOF_SHA"
grep -q '^RTP infeas$' prior/model_589/proof.vipr
grep -q '^DER 803$' prior/model_589/proof.vipr
! grep -q '^RTP range -inf inf$' prior/model_589/proof.vipr
cp prior/model_589/proof.vipr replay/model_589/proof.vipr
cp prior/model_589/scip.stdout replay/model_589/scip.stdout
grep -q 'SCIP Status        : problem is solved \[infeasible\]' replay/model_589/scip.stdout
grep -q 'presolving (0 rounds' replay/model_589/scip.stdout

sudo apt-get update
sudo apt-get install -y build-essential cmake ninja-build libgmp-dev
git clone https://github.com/scipopt/vipr.git vipr
git -C vipr checkout "$VIPR_COMMIT"
cmake -S vipr/code -B vipr/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DVIPRCOMP=OFF
cmake --build vipr/build --target viprchk -j 2
git -C vipr rev-parse HEAD > replay/vipr_commit.txt
test "$(cat replay/vipr_commit.txt)" = "$VIPR_COMMIT"
sha256sum vipr/build/viprchk > replay/viprchk_sha256.txt

set +e
vipr/build/viprchk replay/model_589/proof.vipr > replay/model_589/viprchk.stdout 2> replay/model_589/viprchk.stderr
rc=$?
set -e
echo "$rc" > replay/model_589/viprchk_returncode.txt
cat replay/model_589/viprchk.stdout
cat replay/model_589/viprchk.stderr
test "$rc" = 0
grep -q 'Successfully verified infeasibility' replay/model_589/viprchk.stdout
echo CERTIFIED_UNSAT > replay/model_589/mathematical_status.txt
sha256sum replay/model_589/* > replay/model_589/SHA256SUMS

python3 - <<'PY'
import hashlib,json
from pathlib import Path
def sh(p): return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
d={'schema':'rank5_model589_exact_scip_vipr_cold_replay_v2','model_id':589,'model_sha256':'d7e26cb20c2629ecd7b0b148f05977616e084951db5d19a8932855f3cd92c57b','lp_sha256':sh(Path('replay/model_589/model.lp')),'proof_sha256':sh(Path('replay/model_589/proof.vipr')),'proof_derivations':803,'proof_target':'infeas','vipr_commit':Path('replay/vipr_commit.txt').read_text().strip(),'checker_returncode':int(Path('replay/model_589/viprchk_returncode.txt').read_text()),'status':Path('replay/model_589/mathematical_status.txt').read_text().strip()}
Path('replay/summary.json').write_text(json.dumps(d,indent=2,sort_keys=True)+'\n')
PY
find replay -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > replay/SHA256SUMS
echo MODEL_589_EXACT_SCIP_VIPR_COLD_REPLAY_PASS
