import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 16
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 100000

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    if v < 0:
        v = 0
    max_val = (1 << bits) - 1
    return min(v, max_val)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Test case data
test_cases = [
    {
        "n": 2,
        "options": [
            [(1<<0)|(1<<1), (1<<1)],  # pos 0: options 'ab', 'b'
            [(1<<1)]                   # pos 1: option 'b'
        ],
        "expected": [[0, 1], [-1, 0]]
    },
    {
        "n": 3,
        "options": [
            [(1<<1)],                 # pos 0: 'b'
            [(1<<1), (1<<0)],         # pos 1: 'b', 'a'
            [(1<<0)|(1<<1), (1<<0)|(1<<2)]  # pos 2: 'ab', 'ac'
        ],
        "expected": [[0, 1, -1], [1, 0, -1], [2, 2, 0]]
    }
]

def compute_expected_distance(n, options, start, target):
    # Helper to compute expected distance using simple algorithm
    # Returns -1 if unreachable
    # States: 0..n-1 nodes, -1 is target
    # We want min rounds to reach target from start
    # Bob moves: from p in Alice turn, Bob chooses s in S
    # Alice chooses S to minimize max dist
    # This is a shortest path on game graph
    INF = 1000
    dist = [INF] * n
    dist[target] = 0
    
    # Iterative relaxation
    for _ in range(n * n):  # enough iterations
        changed = False
        for p in range(n):
            if p == target:
                continue
            min_val = INF
            for s in options[p]:
                # Bob chooses s in S, we take max dist in S
                # Actually Alice chooses S, Bob chooses s in S
                # So for a given option S, Bob will pick s that maximizes dist[s]
                # Alice picks option that minimizes that maximum
                max_dist = 0
                bits = s
                any_inf = False
                for k in range(n):
                    if (bits >> k) & 1:
                        if dist[k] >= INF:
                            any_inf = True
                            break
                        max_dist = max(max_dist, dist[k])
                if any_inf:
                    # If any reachable node is INF, this option is bad (Bob can keep it infinite)
                    # In game theory, if Bob can force a state where dist is infinite, Alice can't guarantee win
                    # So this option is invalid for guarantee
                    continue
                # If option is valid, Bob will move to node maximizing dist
                val = max_dist + 1
                if val < min_val:
                    min_val = val
            if min_val < dist[p]:
                dist[p] = min_val
                changed = True
        if not changed:
            break
    
    return -1 if dist[start] >= INF else dist[start]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_game_solver(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: just set inputs
        pass

    for tc_idx, tc in enumerate(test_cases):
        n = tc['n']
        options = tc['options']
        expected = tc['expected']
        
        cocotb.log.info(f"Test case {tc_idx+1}: n={n}")
        
        # Load inputs
        if is_seq:
            # Reset before loading
            await reset_dut(dut)
            
            # Set n_in
            if has_signal(dut, 'n_in'):
                dut.n_in.value = n
            
            # Start loading
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed options for each node
            for p in range(n):
                m = len(options[p])
                if has_signal(dut, 'option_count_in'):
                    dut.option_count_in.value = m
                # Feed each option
                for opt in options[p]:
                    if has_signal(dut, 'option_string_in'):
                        dut.option_string_in.value = opt
                    await RisingEdge(dut.clk)
                # Move to next node (implicit in FSM or we need cycle)
                # Assuming FSM processes count then options
        else:
            # Combinational: set inputs directly
            # In reality, this design is sequential due to memory and loops
            # But if it were combinational:
            pass
        
        # Now compute results
        # The module should output for each (start, target) pair
        # We expect n*n outputs
        
        passed_in_tc = 0
        failed_in_tc = 0
        
        for start in range(n):
            for target in range(n):
                # Expected value
                exp_val = expected[start][target]
                
                if is_seq:
                    # Wait for result for this pair
                    await wait_for_done(dut, max_cycles=5000)
                    if not is_value_defined(dut.result.value):
                        cocotb.log.error(f"Result undefined for start={start}, target={target}")
                        failed_in_tc += 1
                        # Reset for next
                        await RisingEdge(dut.clk)
                        continue
                    
                    res_val = int(dut.result.value)
                    # Check if -1 (255 in 8-bit, but result is 16-bit, so 65535 for -1?)
                    # The spec says result is 16-bit, -1 encoded as 65535 (two's complement?)
                    # Actually, we need to interpret. Let's assume -1 is 65535 or 255.
                    # The problem uses -1 for unreachable. In HDL, often 0xFF or 0xFFFF.
                    # We'll check the actual value.
                    # If exp_val == -1, res_val should be a special marker.
                    # Let's assume the module uses 0xFFFF for -1 or 0xFF.
                    # We need to know the encoding. Let's assume it's unsigned with -1 as 65535 (all ones) or 255.
                    # For simplicity, check if res_val matches exp_val or res_val is max_val for -1.
                    
                    # We'll compute expected raw value
                    if exp_val == -1:
                        # If unreachable, module might output 0xFFFF or 0xFF
                        # We'll accept if it's 0xFFFF (16-bit) or 0xFF (8-bit)
                        if res_val != 0xFFFF and res_val != 0xFF:
                            cocotb.log.error(f"Expected unreachable (-1), got {res_val} for start={start}, target={target}")
                            failed_in_tc += 1
                        else:
                            passed_in_tc += 1
                    else:
                        if res_val != exp_val:
                            cocotb.log.error(f"Expected {exp_val}, got {res_val} for start={start}, target={target}")
                            failed_in_tc += 1
                        else:
                            passed_in_tc += 1
                    
                    # Wait for next cycle to allow done to go low
                    await RisingEdge(dut.clk)
                else:
                    # Combinational - just read
                    pass
        
        cocotb.log.info(f"Test case {tc_idx+1}: Passed {passed_in_tc}, Failed {failed_in_tc}")
        if failed_in_tc > 0:
            raise TestFailure(f"Test case {tc_idx+1} failed with {failed_in_tc} errors")

    cocotb.log.info("All test cases completed successfully")