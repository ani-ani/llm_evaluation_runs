import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
NODE_BITS = 4
MAX_NODES = 8
MAX_EDGES = 16
CLK_NS = 10

# Helper functions
def is_value_defined(v):
    try:
        int(v); return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def clamp_to_width(v, bits):
    if v < 0: v = 0
    max_val = (1 << bits) - 1
    return v if v <= max_val else max_val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_fixed(f, bits=8):
    return int(f * (1 << bits))

def from_fixed(v, bits=8):
    return v / (1 << bits)

# Async helpers
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Test case 1: 3 nodes, 2 edges, 1 exit
# 1-2:7, 2-3:8. Exit:1. Bro:3, Police:2
# Bro dist to 1: 15. Police dist to 1: 7.
# Ratio: 160 * 15 / 7 = 342.85 > max speed (255.99) -> IMPOSSIBLE (scaled)
# In original: 342.8 > 255 max? No, 255 is max in spec? No, limit is actual speed.
# Wait, input constraints say speed is minimal required.
# In test case 1, output is IMPOSSIBLE. 
# Let's verify: Bro 3->2->1 (15). Police at 2, dist to 1 is 7.
# Bro time: 15 / S_bro. Police time: 7 / 160.
# Safe if 15 / S_bro < 7 / 160 (arrive earlier)? 
# Actually "if brothers ever end up at same point... caught".
# Brothers must reach exit safely.
# If Bro reaches exit at time T_b, Police reaches exit at T_p.
# If T_b < T_p, safe (strictly).
# 15/S < 7/160 -> S > 15*160/7 = 342.85 km/h.
# Brothers max speed? Not specified, but they want MINIMAL.
# If min speed > 255? Or just impossible to meet strict inequality?
# In test case 2: 3 nodes. 1-2:7, 2-3:8. Exit:1. Bro:2, Police:3.
# Bro dist to 1: 7. Police dist to 1: 15.
# 7/S < 15/160 -> S > 7*160/15 = 74.66 km/h. Correct.

# Since hardware sim needs discrete values, we simulate the Floyd-Warshall logic.
# We will simplify graph to 4 nodes max for simulation speed if needed, but spec says 8.

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_police_escape(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Cases (Scaled down for 8-bit graph)
    # Case 1: IMPOSSIBLE (requires speed > 255.99)
    # Nodes: 3 (1,2,3). Edges: 1-2 len 7, 2-3 len 8. Exit: 1. Bro: 3, Police: 2.
    # Bro path: 3->2->1 (15). Police path: 2->1 (7).
    # Req Speed: 160 * 15 / 7 = 342.8 > 255 (max Q8.8 int part? No, Q8.8 max 255.99)
    # So it's impossible if we constrain max speed to 255.99? 
    # The problem says "minimal speed", implying it might be arbitrarily high or impossible.
    # In hardware, we constrain search to 0-255.99.
    test_cases = [
        {
            "n": 3, "m": 2, "e": 1,
            "edges": [(1, 2, 7), (2, 3, 8)],
            "exits": [1],
            "bro": 3, "police": 2,
            "expected": "IMPOSSIBLE", # Because 342.8 > 255
            "desc": "Impossible (Speed > 255)"
        },
        {
            "n": 3, "m": 2, "e": 1,
            "edges": [(1, 2, 7), (2, 3, 8)],
            "exits": [1],
            "bro": 2, "police": 3,
            "expected": 74.666, 
            "desc": "Simple Path"
        },
        {
            "n": 4, "m": 4, "e": 2,
            "edges": [(1, 4, 1), (1, 3, 4), (3, 4, 10), (2, 3, 30)],
            "exits": [1, 2],
            "bro": 3, "police": 4,
            "expected": 137.14,
            "desc": "Multiple Exits"
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: {tc['desc']}")
        
        # Configure DUT
        dut.node_count.value = tc['n']
        dut.exit_count.value = tc['e']
        dut.bro_start.value = tc['bro'] - 1 # 0-indexed if internal
        dut.police_start.value = tc['police'] - 1

        # Load Edges (Sequential input assumed based on spec)
        # If interface is parallel arrays, we write them directly.
        # Assuming sequential loading via `edge_src`, `edge_dst`, `edge_len` signals with index
        # or assuming the testbench can write to internal arrays if exposed.
        # For this spec, let's assume we write to parallel ports for simplicity in simulation,
        # or use a load sequence.
        # Let's simulate the behavior: The module should have inputs for edges.
        # We will write to `edge_src[i]`, etc. 
        for idx, (src, dst, length) in enumerate(tc['edges']):
            # Check if arrays exist or individual ports
            if has_signal(dut, f'edge_src_{idx}'):
                getattr(dut, f'edge_src_{idx}').value = src - 1
                getattr(dut, f'edge_dst_{idx}').value = dst - 1
                getattr(dut, f'edge_len_{idx}').value = length
            else:
                # Fallback to array access if `edge_src` is array
                dut.edge_src[idx].value = src - 1
                dut.edge_dst[idx].value = dst - 1
                dut.edge_len[idx].value = length
        
        # Load Exits
        for idx, exit_node in enumerate(tc['exits']):
            if has_signal(dut, f'exit_{idx}'):
                getattr(dut, f'exit_{idx}').value = exit_node - 1
            else:
                dut.exit_list[idx].value = exit_node - 1

        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait
        await wait_for_done(dut)

        # Check Result
        if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
            result_str = "IMPOSSIBLE"
            if tc['expected'] != "IMPOSSIBLE":
                raise TestFailure(f"Test {i+1}: Expected {tc['expected']}, got IMPOSSIBLE")
        else:
            if not is_value_defined(dut.result_speed.value):
                raise TestFailure(f"Test {i+1}: Result speed undefined")
            
            result_speed_q88 = int(dut.result_speed.value)
            result_speed_float = from_fixed(result_speed_q88, bits=8)
            
            # Allow tolerance
            expected = tc['expected']
            tolerance = 0.5 # Loose tolerance for fixed point/binary search steps
            
            if abs(result_speed_float - expected) > tolerance:
                 raise TestFailure(f"Test {i+1}: Expected {expected}, got {result_speed_float}")

        # Reset for next test
        await reset_dut(dut)
