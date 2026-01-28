import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference for the problem
def python_solve(n, m, edges):
    # Create adjacency and reachability matrices
    adj = [[0] * n for _ in range(n)]
    reach = [[0] * n for _ in range(n)]
    
    for u, v in edges:
        adj[u][v] = 1
        reach[u][v] = 1
        
    # Floyd-Warshall for Transitive Closure
    for k in range(n):
        for i in range(n):
            if reach[i][k]:
                for j in range(n):
                    if reach[k][j]:
                        reach[i][j] = 1
                        
    # Count valid new edges
    count = 0
    for u in range(n):
        for v in range(n):
            if u == v:
                continue
            if adj[u][v] == 0 and reach[u][v] == 0:
                count += 1
    return count

# Test cases from prompt
TEST_CASES = [
    {"n": 2, "m": 1, "edges": [(0, 1)], "expected": 0},
    {"n": 5, "m": 7, "edges": [(3, 2), (4, 0), (3, 1), (0, 3), (4, 2), (1, 0), (3, 4)], "expected": 2},
    {"n": 3, "m": 3, "edges": [(0, 2), (2, 1), (1, 0)], "expected": 0},
    {"n": 3, "m": 2, "edges": [(0, 2), (2, 1)], "expected": 1},
]

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_round_trips(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    for tc_idx, tc in enumerate(TEST_CASES):
        cocotb.log.info(f"Running Test Case {tc_idx + 1}: n={tc['n']}, m={tc['m']}")
        
        # Load Inputs
        dut.n.value = tc['n']
        dut.m.value = tc['m']
        
        # Load Edges
        # Clear edge array first (optional but good practice if not auto-cleared)
        if has_signal(dut, 'edges'):
            for i in range(32): # Max edges in spec
                dut.edges[i].src.value = 0
                dut.edges[i].dst.value = 0
        else:
            # Handle packed or individual signals if specified differently
            # Assuming array of structs or parallel arrays based on spec logic
            pass

        # Fill edges
        for i, (u, v) in enumerate(tc['edges']):
            if has_signal(dut, 'edges'):
                dut.edges[i].src.value = u
                dut.edges[i].dst.value = v
            elif has_signal(dut, f'edge_src_{i}'):
                getattr(dut, f'edge_src_{i}').value = u
                getattr(dut, f'edge_dst_{i}').value = v
            else:
                # Fallback for flattened array
                # Assuming `edges` is a 32-entry array of 8-bit packed values (4+4)
                packed = (u << 4) | v
                dut.edges[i].value = packed

        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check Result
        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
            raise TestFailure(f"Test {tc_idx+1} failed: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {tc_idx+1} Passed: {result}")
        
        # Prepare for next test
        await reset_dut(dut)

    cocotb.log.info("All tests passed!")