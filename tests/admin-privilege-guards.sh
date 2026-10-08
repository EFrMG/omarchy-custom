#!/usr/bin/env bash
# Exercise the privilege guards without changing real accounts or sudoers files.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/mock" "$fixture/sudoers"
export TEST_FIXTURE=$fixture
export PATH="$fixture/mock:$PATH"

cat >"$fixture/mock/getent" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == passwd ]]; then
  case ${2:-} in
    '') printf 'alice:x:1000:1000::/home/alice:/bin/bash\nbob:x:1001:1001::/home/bob:/bin/bash\ncarol:x:1002:1002::/home/carol:/bin/bash\n' ;;
    alice|bob|carol) printf '%s:x:1000:1000::/home/%s:/bin/bash\n' "$2" "$2" ;;
    *) exit 2 ;;
  esac
elif [[ $1 == group ]]; then
  [[ $2 == wheel ]]
fi
EOF
cat >"$fixture/mock/id" <<'EOF'
#!/usr/bin/env bash
case $1 in
  -un) printf '%s\n' "${TEST_ACTOR:-carol}" ;;
  -gn) printf '%s\n' "$2" ;;
  -nG)
    case $2 in
      alice) if [[ ${TEST_ALICE_WHEEL:-1} == 1 ]]; then echo 'alice wheel'; else echo alice; fi ;;
      bob) if [[ ${TEST_BOB_WHEEL:-0} == 1 ]]; then echo 'bob wheel'; else echo bob; fi ;;
      carol) echo carol ;;
    esac ;;
  alice|bob|carol) [[ ! -e "$TEST_FIXTURE/deleted-$1" ]] ;;
  *) exit 2 ;;
esac
EOF
cat >"$fixture/mock/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
map_path() {
  case $1 in
    /etc/sudoers.d/*) printf '%s/sudoers/%s' "$TEST_FIXTURE" "${1##*/}" ;;
    *) printf '%s' "$1" ;;
  esac
}
cmd=$1; shift
case $cmd in
  test)
    flag=$1; shift
    /usr/bin/test "$flag" "$(map_path "$1")" ;;
  cat)
    [[ $1 == -- ]] && shift
    /usr/bin/cat -- "$(map_path "$1")" ;;
  rm)
    [[ $1 == -- ]] && shift
    /usr/bin/rm -- "$(map_path "$1")" ;;
  -l)
    [[ $1 == -U ]] || exit 2
    user=$2
    if [[ -e "$TEST_FIXTURE/sudoers/$user" || ${TEST_EXTERNAL_SUDO:-} == "$user" ]]; then
      echo "User $user may run commands via sudo"
    else
      exit 1
    fi ;;
  usermod) printf 'usermod %s\n' "$*" >>"$TEST_FIXTURE/actions" ;;
  userdel) touch "$TEST_FIXTURE/deleted-${*: -1}" ;;
  loginctl|visudo) : ;;
  *) echo "unexpected sudo command: $cmd $*" >&2; exit 2 ;;
esac
EOF
chmod +x "$fixture/mock/"*

reset_fixture() {
  rm -f -- "$fixture/sudoers/"* "$fixture/actions" "$fixture/deleted-"* 2>/dev/null || true
  export TEST_ACTOR=carol TEST_ALICE_WHEEL=1 TEST_BOB_WHEEL=1 TEST_EXTERNAL_SUDO=
  unset SUDO_USER || true
}
expect_failure() {
  local expected=$1; shift
  if "$@" >"$fixture/out" 2>&1; then
    echo "expected failure: $*" >&2; exit 1
  fi
  grep -Fq -- "$expected" "$fixture/out" || { cat "$fixture/out" >&2; exit 1; }
}
expect_success() {
  "$@" >"$fixture/out" 2>&1 || { cat "$fixture/out" >&2; exit 1; }
}
managed_rule() { printf 'alice ALL=(ALL) ALL\n' >"$fixture/sudoers/alice"; }

reset_fixture
printf 'alice ALL=(ALL) ALL\nbob ALL=(ALL) ALL\n' >"$fixture/sudoers/alice"
# Every path that may delete or replace this file must reject the second rule.
expect_failure 'not exactly one managed rule' "$repo/bin/omarchy-set-privileges" alice --level none --yes --force-lockout
expect_failure 'not exactly one managed rule' "$repo/bin/omarchy-set-privileges" alice --level nopasswd --yes
expect_failure 'not exactly one managed rule' "$repo/bin/omarchy-remove-user" alice --yes --force-lockout
expect_failure 'not exactly one managed rule' "$repo/install.sh" --dry-run --skip-lint --add-user alice --sudo
grep -Fq 'sudo visudo -f /etc/sudoers.d/alice' "$fixture/out"
[[ -f $fixture/sudoers/alice && ! -e $fixture/deleted-alice ]]

reset_fixture
managed_rule
mv "$fixture/sudoers/alice" "$fixture/elsewhere"
ln -s "$fixture/elsewhere" "$fixture/sudoers/alice"
expect_failure 'not exactly one managed rule' "$repo/bin/omarchy-set-privileges" alice --level none --yes --force-lockout
[[ -L $fixture/sudoers/alice ]]

reset_fixture
managed_rule
export SUDO_USER=alice
expect_failure 'refusing to remove your own sudo' "$repo/bin/omarchy-set-privileges" alice --level none --yes
[[ -f $fixture/sudoers/alice ]]

reset_fixture
printf 'bob ALL=(ALL) ALL\n' >"$fixture/sudoers/bob"
export TEST_ALICE_WHEEL=0 TEST_BOB_WHEEL=0
expect_failure 'no wheel administrator would remain' "$repo/bin/omarchy-set-privileges" bob --level none --yes
[[ -f $fixture/sudoers/bob ]]

reset_fixture
managed_rule
export TEST_EXTERNAL_SUDO=alice
expect_success "$repo/bin/omarchy-set-privileges" alice --level none --yes
grep -Fq 'still has effective sudo privileges' "$fixture/out"
grep -Fq 'Next: review /etc/sudoers and /etc/sudoers.d' "$fixture/out"
[[ ! -e $fixture/sudoers/alice ]]

reset_fixture
export TEST_EXTERNAL_SUDO=alice
expect_success "$repo/bin/omarchy-set-privileges" alice --level none --yes
grep -Fq 'nothing to remove' "$fixture/out"
grep -Fq 'still has effective sudo privileges' "$fixture/out"

reset_fixture
export SUDO_USER=alice
expect_failure 'refusing to remove your own wheel membership' "$repo/bin/omarchy-change-groups" alice --remove wheel --yes
[[ ! -e $fixture/actions ]]
expect_success "$repo/bin/omarchy-change-groups" alice --remove wheel --yes --force-lockout
[[ -s $fixture/actions ]]

reset_fixture
export TEST_BOB_WHEEL=0
expect_failure 'no other wheel administrator' "$repo/bin/omarchy-change-groups" alice --remove wheel --yes
[[ ! -e $fixture/actions ]]
expect_failure 'no other wheel administrator' "$repo/bin/omarchy-remove-user" alice --yes
[[ ! -e $fixture/deleted-alice ]]
expect_success "$repo/bin/omarchy-remove-user" alice --yes --force-lockout
[[ -e $fixture/deleted-alice ]]

echo 'admin privilege guards passed'
