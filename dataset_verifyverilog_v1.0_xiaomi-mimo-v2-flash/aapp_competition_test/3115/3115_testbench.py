import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPERS
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# CONSTANTS
MAX_CYCLES = 4096
CLK_NS = 10

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'match_valid'): dut.match_valid.value = 0
    if has_signal(dut, 'match_end'): dut.match_end.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2048):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# TEST HELPER FOR SPECIFIC CASES
def python_check_consistency(num_players, matches):
    # Simple python reference for validation logic
    # Adjacency list for strict edges
    adj = {i: [] for i in range(num_players)}
    # Equality sets
    eq = {i: {i} for i in range(num_players)}
    
    for k, op, l in matches:
        if op == '=':
            # Merge sets
            set_k = None
            set_l = None
            for s in eq.values():
                if k in s: set_k = s
                if l in s: set_l = s
            if set_k is not None and set_l is not None and set_k is not set_l:
                set_k.update(set_l)
                for item in set_l:
                    eq[item] = set_k
            elif set_k is None and set_l is not None:
                set_l.add(k)
                eq[k] = set_l
            elif set_l is None and set_k is not None:
                set_k.add(l)
                eq[l] = set_k
            elif set_k is None and set_l is None:
                new_set = {k, l}
                eq[k] = new_set
                eq[l] = new_set
        else: # '>'
            adj[k].append(l)
    
    # Check consistency
    # 1. Direct conflict: A=B and A>B (or B>A)
    # 2. Cycle: A>B...>A
    
    # Check cycles using Floyd-Warshall on 16 nodes or DFS
    # We need to collapse equal nodes
    nodes = list(eq.keys())
    unique_groups = []
    visited_groups = set()
    for k, s in eq.items():
        id_s = id(s)
        if id_s not in visited_groups:
            unique_groups.append(s)
            visited_groups.add(id_s)
    
    # Map original node to group index
    group_map = {}
    for idx, g in enumerate(unique_groups):
        for node in g:
            group_map[node] = idx
    
    num_groups = len(unique_groups)
    group_adj = [[False] * num_groups for _ in range(num_groups)]
    
    # Build group graph
    for u in range(num_players):
        for v in adj[u]:
            gu = group_map[u]
            gv = group_map[v]
            if gu == gv:
                return False # Conflict: A=B and A>B
            group_adj[gu][gv] = True
            
    # Detect cycle in group graph (Floyd-Warshall)
    for k in range(num_groups):
        for i in range(num_groups):
            for j in range(num_groups):
                if group_adj[i][k] and group_adj[k][j]:
                    group_adj[i][j] = True
                    if i == j:
                        return False # Cycle detected
    
    return True

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_consistency_checker(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational circuit assumption (less likely for this complexity)
        dut.rst_n.value = 1
    
    # Test Cases
    test_cases = [
        (3, [(0, '>', 1), (1, '=', 2), (0, '=', 2)], False), # Inconsistent
        (5, [(0, '=', 1), (1, '=', 2), (3, '=', 4), (0, '>', 3), (1, '>', 4)], True), # Consistent
        (6, [(0, '>', 1), (1, '>', 2), (3, '=', 4), (4, '=', 5), (5, '>', 3)], False), # Inconsistent (Cycle 3>4>5>3)
    ]
    
    for case_idx, (num_p, matches, expected_consistent) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {case_idx + 1} with {len(matches)} matches")
        
        # Reset for new test case
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # If no start signal, assume continuous input after reset
            pass
            
        # Feed matches
        for k, op, l in matches:
            op_code = 0 if op == '=' else 1
            dut.player_a.value = clamp_to_width(k, 4)
            dut.player_b.value = clamp_to_width(l, 4)
            dut.match_type.value = clamp_to_width(op_code, 2)
            dut.match_valid.value = 1
            await RisingEdge(dut.clk)
            
        # Signal end of input
        dut.match_valid.value = 0
        dut.match_end.value = 1
        await RisingEdge(dut.clk)
        dut.match_end.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.consistent.value):
            raise TestFailure("Result signal 'consistent' is undefined")
        
        result = int(dut.consistent.value)
        expected_val = 1 if expected_consistent else 0
        
        if result != expected_val:
            raise TestFailure(f"Case {case_idx+1}: Expected {expected_val} ({'consistent' if expected_consistent else 'inconsistent'}), got {result}")
        
        cocotb.log.info(f"Case {case_idx+1}: PASS")
