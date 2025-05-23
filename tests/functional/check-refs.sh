#!/usr/bin/env bash

source common.sh

TODO_NixOS

clearStore

RESULT=$TEST_ROOT/result

dep=$(nix-build -o "$RESULT" check-refs.nix -A dep)

# test1 references dep, not itself.
test1=$(nix-build -o "$RESULT" check-refs.nix -A test1)
nix-store -q --references "$test1" | grepQuietInverse "$test1"
nix-store -q --references "$test1" | grepQuiet "$dep"

# test2 references src, not itself nor dep.
test2=$(nix-build -o "$RESULT" check-refs.nix -A test2)
nix-store -q --references "$test2" | grepQuietInverse "$test2"
nix-store -q --references "$test2" | grepQuietInverse "$dep"
nix-store -q --references "$test2" | grepQuiet aux-ref

# test3 should fail (unallowed ref).
(! nix-build -o "$RESULT" check-refs.nix -A test3)

# test4 should succeed.
nix-build -o "$RESULT" check-refs.nix -A test4

# test5 should succeed.
nix-build -o "$RESULT" check-refs.nix -A test5

# test6 should fail (unallowed self-ref).
(! nix-build -o "$RESULT" check-refs.nix -A test6)

# test7 should succeed (allowed self-ref).
nix-build -o "$RESULT" check-refs.nix -A test7

# test8 should fail (toFile depending on derivation output).
(! nix-build -o "$RESULT" check-refs.nix -A test8)

# test9 should fail (disallowed reference).
(! nix-build -o "$RESULT" check-refs.nix -A test9)

# test10 should succeed (no disallowed references).
nix-build -o "$RESULT" check-refs.nix -A test10

if ! isTestOnNixOS; then
    # If we have full control over our store, we can test some more things.

    if isDaemonNewer 2.12pre20230103; then
        if ! isDaemonNewer 2.16.0; then
            enableFeatures discard-references
            restartDaemon
        fi

        # test11 should succeed.
        test11=$(nix-build -o "$RESULT" check-refs.nix -A test11)
        [[ -z $(nix-store -q --references "$test11") ]]
    fi

fi

if isDaemonNewer "2.28pre20241225"; then
    # test12 should fail (syntactically invalid).
    expectStderr 1 nix-build -vvv -o "$RESULT" check-refs.nix -A test12 >"$TEST_ROOT/test12.stderr"
    grepQuiet -F "output check for 'lib' contains an illegal reference specifier 'dev', expected store path or output name (one of [lib, out])" < "$TEST_ROOT/test12.stderr"
fi
