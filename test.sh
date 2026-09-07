#!/bin/bash
# g02b — The Stakes / test.sh
#
# Builds the game, then checks the physics/collision/event logic
# deterministically -- compiled and linked WITHOUT SDL2 or SDL2_mixer
# at all (map.c, player.c, and camera.c never call an actual SDL
# function, only use compile-time constants/types from <SDL2/SDL.h>,
# so the logic layer needs no display, no audio device, and neither
# library at link time -- same discipline g02a established).
#
# Copy this file and fixtures/test-map.txt into your working directory,
# build with 'make re', then run:
#
#   bash test.sh

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="${SCRIPT_DIR}/fixtures"

# ── colour ────────────────────────────────────────────────────────────────────

if [[ ! -t 1 ]]; then
    C_GREEN=""
    C_RED=""
    C_BOLD=""
    C_RESET=""
else
    C_GREEN="\033[0;32m"
    C_RED="\033[0;31m"
    C_BOLD="\033[1m"
    C_RESET="\033[0m"
fi

# ── state ─────────────────────────────────────────────────────────────────────

pass_count=0
fail_count=0
WORK_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# ── helpers ───────────────────────────────────────────────────────────────────

hr() {
    echo "────────────────────────────────────────────────────────────────"
}

banner() {
    hr
    echo "  g02b — The Stakes / test.sh"
    hr
}

pass() {
    local label="$1"
    printf "  ${C_GREEN}PASS${C_RESET}  %s\n" "$label"
    pass_count=$((pass_count + 1))
}

fail() {
    local label="$1"
    local detail="${2:-}"
    printf "  ${C_RED}FAIL${C_RESET}  %s\n" "$label"
    if [[ -n "$detail" ]]; then
        echo "        $detail"
    fi
    fail_count=$((fail_count + 1))
}

banner

# ── build the real game ───────────────────────────────────────────────────────

echo "Building..."
build_log=$(make re 2>&1)
build_status=$?
if [[ "$build_status" -ne 0 ]]; then
    fail "build succeeds" "make re failed:"
    echo "$build_log"
    exit 1
fi
pass "build succeeds"

if echo "$build_log" | grep -qi "warning"; then
    fail "build produces no warnings" "$(echo "$build_log" | grep -i warning)"
else
    pass "build produces no warnings"
fi

if [[ -x ./platformer ]]; then
    pass "platformer binary exists"
else
    fail "platformer binary exists"
fi

# ── build the SDL2-free logic tester ─────────────────────────────────────────

if [[ ! -f "${FIXTURES}/test-map.txt" ]]; then
    fail "fixtures/test-map.txt found" "keep the g02b-the-stakes clone alongside your working directory"
    exit 1
fi
cp "${FIXTURES}/test-map.txt" "$WORK_DIR/test-map.txt"

cat > "$WORK_DIR/test_logic.c" <<'TESTC'
#include <stdio.h>
#include <string.h>
#include "map.h"
#include "player.h"
#include "camera.h"

static int  g_pass = 0;
static int  g_fail = 0;

static void check_int(char const *label, int got, int want)
{
    if (got == want)
    {
        printf("PASS  %s (got %d)\n", label, got);
        g_pass++;
    }
    else
    {
        printf("FAIL  %s (got %d, want %d)\n", label, got, want);
        g_fail++;
    }
}

static char const *event_name(t_event event)
{
    if (event == EVENT_JUMPED)
        return ("EVENT_JUMPED");
    if (event == EVENT_LANDED)
        return ("EVENT_LANDED");
    if (event == EVENT_COLLECTED)
        return ("EVENT_COLLECTED");
    if (event == EVENT_DIED)
        return ("EVENT_DIED");
    if (event == EVENT_WON)
        return ("EVENT_WON");
    return ("EVENT_NONE");
}

static void check_event(char const *label, t_event got, t_event want)
{
    if (got == want)
    {
        printf("PASS  %s (got %s)\n", label, event_name(got));
        g_pass++;
    }
    else
    {
        printf("FAIL  %s (got %s, want %s)\n", label, event_name(got),
            event_name(want));
        g_fail++;
    }
}

int main(void)
{
    t_map       map;
    t_player    p;
    t_camera    cam;
    Uint8       keys[SDL_NUM_SCANCODES];
    int         i;
    t_event     ev;

    if (!map_load(&map, "test-map.txt"))
    {
        printf("FAIL  map_load\n");
        return (1);
    }
    check_int("map width", map.width, 40);
    check_int("map height", map.height, 6);

    /* g02a's own collision-correctness suite, unchanged -- the new
     * fixture map keeps the same wall/platform/ground geometry, only
     * adding a coin, a hazard, and start/goal markers on previously
     * empty tiles, so none of this should have moved. */
    player_init(&p, 32.0f, 0.0f);
    i = 0;
    while (i < 100)
    {
        player_update_physics(&p);
        player_resolve_collision(&p, &map);
        i++;
    }
    check_int("free fall lands on open ground (on_ground)", p.on_ground, 1);
    check_int("free fall lands on open ground (y)", (int)p.y, 116);

    player_init(&p, 512.0f, 0.0f);
    i = 0;
    while (i < 100)
    {
        player_update_physics(&p);
        player_resolve_collision(&p, &map);
        i++;
    }
    check_int("free fall lands on the platform (on_ground)", p.on_ground, 1);
    check_int("free fall lands on the platform (y)", (int)p.y, 20);

    player_init(&p, 32.0f, 0.0f);
    i = 0;
    while (i < 100)
    {
        player_update_physics(&p);
        player_resolve_collision(&p, &map);
        i++;
    }
    i = 0;
    while (i < 100)
    {
        p.vx = MOVE_SPEED;
        player_update_physics(&p);
        player_resolve_collision(&p, &map);
        i++;
    }
    check_int("walking right stops at the wall (x)", (int)p.x, 164);
    check_int("walking right stops at the wall (still grounded)", p.on_ground, 1);

    player_init(&p, 100.0f, 116.0f);
    p.on_ground = 1;
    i = 0;
    while (i < 60)
    {
        p.vx = -MOVE_SPEED;
        player_update_physics(&p);
        player_resolve_collision(&p, &map);
        i++;
    }
    check_int("walking left stops cleanly at the map's left edge", (int)p.x, 0);

    player_init(&p, 32.0f, 0.0f);
    i = 0;
    while (i < 100)
    {
        player_update_physics(&p);
        player_resolve_collision(&p, &map);
        i++;
    }
    i = 0;
    while (i < 20)
    {
        p.vx = 0.0f;
        player_update_physics(&p);
        player_resolve_collision(&p, &map);
        if (!p.on_ground)
            break;
        i++;
    }
    check_int("on_ground never drops while genuinely at rest", i, 20);

    camera_init(&cam);
    camera_update(&cam, 0.0f, &map);
    check_int("camera clamps at the left map edge", cam.x, 0);
    camera_update(&cam, 1280.0f, &map);
    check_int("camera clamps at the right map edge", cam.x, 480);

    /* g02b: event-returning player functions. */
    memset(keys, 0, sizeof(keys));
    player_init(&p, 32.0f, 0.0f);
    i = 0;
    while (i < 100)
    {
        player_update_physics(&p);
        player_resolve_collision(&p, &map);
        i++;
    }
    keys[SDL_SCANCODE_SPACE] = 1;
    ev = player_handle_input(&p, keys);
    check_event("jump input while grounded returns EVENT_JUMPED", ev, EVENT_JUMPED);
    keys[SDL_SCANCODE_SPACE] = 0;
    ev = player_handle_input(&p, keys);
    check_event("no input while airborne returns EVENT_NONE", ev, EVENT_NONE);

    player_init(&p, 32.0f, 0.0f);
    ev = EVENT_NONE;
    i = 0;
    while (i < 100 && ev != EVENT_LANDED)
    {
        player_update_physics(&p);
        ev = player_resolve_collision(&p, &map);
        i++;
    }
    check_event("free fall raises EVENT_LANDED exactly once on impact", ev,
        EVENT_LANDED);
    ev = player_resolve_collision(&p, &map);
    check_event("staying grounded the next frame raises no event", ev,
        EVENT_NONE);

    /* g02b: map event queries -- coin at (30, 0), hazard at (30, 1),
     * goal at the fixture's 'G' marker (38, 4), in tile coordinates. */
    player_init(&p, 30.0f * TILE_SIZE, 0.0f);
    ev = map_try_collect(&map, &p);
    check_event("standing on the coin tile returns EVENT_COLLECTED", ev,
        EVENT_COLLECTED);
    check_int("collecting removes the coin from the map", map_tile_at(&map, 30, 0),
        TILE_EMPTY);
    ev = map_try_collect(&map, &p);
    check_event("a collected coin cannot be collected twice", ev, EVENT_NONE);

    player_init(&p, 30.0f * TILE_SIZE, 1.0f * TILE_SIZE);
    ev = map_check_hazard(&map, &p);
    check_event("standing on the hazard tile returns EVENT_DIED", ev, EVENT_DIED);

    player_init(&p, 5.0f * TILE_SIZE, 0.0f);
    ev = map_check_hazard(&map, &p);
    check_event("standing away from any hazard returns EVENT_NONE", ev,
        EVENT_NONE);

    check_int("map_load recorded the fixture's goal_x", map.goal_x,
        38 * TILE_SIZE);
    check_int("map_load recorded the fixture's goal_y", map.goal_y,
        4 * TILE_SIZE);
    player_init(&p, (float)map.goal_x, (float)map.goal_y);
    ev = map_check_goal(&map, &p);
    check_event("standing on the goal tile returns EVENT_WON", ev, EVENT_WON);

    player_init(&p, 5.0f * TILE_SIZE, 0.0f);
    ev = map_check_goal(&map, &p);
    check_event("standing away from the goal returns EVENT_NONE", ev,
        EVENT_NONE);

    map_free(&map);
    printf("\n%d passed, %d failed\n", g_pass, g_fail);
    return (g_fail > 0);
}
TESTC

logic_build_log=$(gcc -Wall -Wextra -I libtci -I . -c "$WORK_DIR/test_logic.c" -o "$WORK_DIR/test_logic.o" 2>&1 \
    && gcc "$WORK_DIR/test_logic.o" map.o player.o camera.o libtci/libtci.a -o "$WORK_DIR/test_logic" 2>&1)
logic_build_status=$?

if [[ "$logic_build_status" -ne 0 ]]; then
    fail "logic tester builds without SDL2/SDL2_mixer" "$logic_build_log"
    exit 1
fi
pass "logic tester builds without SDL2/SDL2_mixer (map.o/player.o/camera.o only)"

echo
echo "Running the logic tester..."
cd "$WORK_DIR"
logic_out=$(./test_logic)
logic_status=$?
cd - > /dev/null

echo "$logic_out" | grep "^PASS\|^FAIL" | while read -r line; do
    echo "  $line"
done

logic_pass_count=$(echo "$logic_out" | grep -c "^PASS")
logic_fail_count=$(echo "$logic_out" | grep -c "^FAIL")
pass_count=$((pass_count + logic_pass_count))
fail_count=$((fail_count + logic_fail_count))

if [[ "$logic_status" -ne 0 ]]; then
    fail "all logic assertions pass" "see failures above"
fi

# ── headless smoke test of the real binary ───────────────────────────────────

echo
echo "Running platformer headless (2s)..."
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout 2 ./platformer "${FIXTURES}/level1.txt"
platformer_status=$?
if [[ "$platformer_status" -eq 124 ]]; then
    pass "platformer runs its event loop for 2s without crashing"
else
    fail "platformer runs its event loop for 2s without crashing" "exit code: $platformer_status"
fi

# ── summary ───────────────────────────────────────────────────────────────────

# ── leak report ─────────────────────────────────────────────────────────────────
#
# Runs one representative invocation under valgrind and REPORTS what it finds.
# It never changes the pass/fail count. A leak is something to look at, not a
# reason to refuse your work — but you should see it, because a program that
# leaks is a program that will eventually be killed by the machine it runs on.
#
# Leaks are split by whose code lost the memory. A loss record whose stack
# names one of your own .c files is yours. One that lives entirely inside
# SDL, Mesa or glibc is not, and there is nothing for you to fix there.

leak_report() {
    local label="$1"; shift
    local log="${WORK_DIR:-/tmp}/leaks.$$.log"
    local mine=0 theirs=0 rec frames

    if ! command -v valgrind >/dev/null 2>&1; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: valgrind is not installed, skipping\n" "$label"
        return 0
    fi

    valgrind --leak-check=full --show-leak-kinds=definite,indirect \
             --error-exitcode=0 --log-file="$log" "$@" >/dev/null 2>&1

    if [[ ! -s "$log" ]]; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: valgrind produced no output\n" "$label"
        return 0
    fi

    # Split the log into loss records and ask, of each, whether any frame
    # points at a source file sitting in this directory.
    while IFS= read -r rec; do
        frames=$(sed -n "${rec}"',/^==[0-9]*== *$/p' "$log")
        # Every record carries valgrind's own malloc frame; that is not yours.
        # A frame is yours only if it names a source file sitting right here.
        local f owned=0
        for f in $(grep -oE '\(([A-Za-z0-9_-]+\.c):[0-9]+\)' <<<"$frames" \
                   | tr -d '()' | cut -d: -f1 | sort -u); do
            [[ "$f" == vg_replace_malloc.c ]] && continue
            [[ -f "$f" ]] && owned=1
        done
        if (( owned )); then
            mine=$((mine + 1))
            if (( mine == 1 )); then
                printf "  ${C_RED}LEAK${C_RESET}  %s — memory lost by your code:\n" "$label"
            fi
            grep -E 'bytes in [0-9,]+ blocks are (definitely|indirectly)' <<<"$frames" \
                | sed 's/^==[0-9]*== /        /'
            grep -oE '\(([A-Za-z0-9_-]+\.c:[0-9]+)\)' <<<"$frames" \
                | grep -v vg_replace_malloc | head -3 | tr -d '()' \
                | sed 's/^/          at /'
        else
            theirs=$((theirs + 1))
        fi
    done < <(grep -nE 'bytes in [0-9,]+ blocks are (definitely|indirectly) lost' "$log" | cut -d: -f1)

    if (( mine == 0 )); then
        printf "  ${C_GREEN}OK${C_RESET}    %s — no memory lost by your code" "$label"
        if (( theirs > 0 )); then
            printf ' (%d leak(s) inside libraries you did not write)' "$theirs"
        fi
        printf '\n'
    else
        printf '        this does not fail the tester — fix it anyway\n'
    fi
    rm -f "$log"
    return 0
}

# The graphical chapters run until you quit them, and a program killed
# mid-loop reports everything it has not freed yet as "lost" -- which would be
# a lie. So this starts a virtual display, lets the program run, sends it a
# 'q', and measures the clean exit.
leak_report_gui() {
    local label="$1"; shift
    if ! command -v valgrind >/dev/null 2>&1; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: valgrind is not installed, skipping\n" "$label"
        return 0
    fi
    if ! command -v xvfb-run >/dev/null 2>&1 || ! command -v xte >/dev/null 2>&1; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: needs xvfb-run and xte for a clean exit, skipping\n" "$label"
        return 0
    fi
    printf "  ${C_BOLD}....${C_RESET}  %s: running under valgrind, this takes a minute\n" "$label"
    local inner="${WORK_DIR:-/tmp}/leak_gui.$$.sh"
    {
        echo "C_GREEN=\"${C_GREEN}\"; C_RED=\"${C_RED}\"; C_BOLD=\"${C_BOLD}\"; C_RESET=\"${C_RESET}\""
        echo "WORK_DIR=\"${WORK_DIR:-/tmp}\""
        declare -f leak_report
        echo '( sleep 12; xte "key q" 2>/dev/null; sleep 5; xte "key q" 2>/dev/null ) &'
        printf 'leak_report %q' "$label"
        printf ' %q' "$@"
        printf '\n'
    } > "$inner"
    timeout 240 xvfb-run -a bash "$inner"
    local rc=$?
    rm -f "$inner"
    if (( rc == 124 )); then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: the program never exited, so there is nothing honest to measure\n" "$label"
        printf "        (a program killed mid-loop reports everything it holds as lost)\n"
    fi
    return 0
}

echo
leak_report_gui "platformer" ./platformer "${FIXTURES}/level1.txt"

echo
hr
printf "  ${C_BOLD}%d passed, %d failed${C_RESET}\n" "$pass_count" "$fail_count"
hr

if [[ "$fail_count" -gt 0 ]]; then
    exit 1
fi
exit 0
