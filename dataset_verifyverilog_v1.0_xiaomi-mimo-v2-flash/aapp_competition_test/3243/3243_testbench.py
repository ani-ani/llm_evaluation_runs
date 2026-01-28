import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants scaled for hardware: n=16, k=8, edges=16
MAX_NODES = 16
MAX_EDGES = 16
MAX_K = 8
DATA_WIDTH = 4
CLK_NS = 10

# --- Helpers ---
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
    if has_signal(dut, 'edge_valid_in'): dut.edge_valid_in.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# --- Test Logic ---
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_isp_merge(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Cases: (n, k, edges, capacities, expected_result)
    test_cases = [
        # Sample 1: 4 nodes, dense graph (already connected). 
        # Capacities 3. Edges: 5 (0-1, 0-3, 1-3, 1-2, 2-3). 
        # n=4, k=2. Result should be yes.
        {
            "n": 4, "k": 2, 
            "edges": [(0,1), (0,3), (1,3), (1,2), (2,3)],
            "caps": [3,3,3,3],
            "expected": 1
        },
        # Sample 2: 5 nodes, k=4. 
        # Edges: (0,1), (2,3), (3,4), (4,2) -> Components: {0,1}, {2,3,4}. 
        # Capacities: [1,1,2,2,2]. 
        # Edges needed to connect: 1. 
        # Degrees: Node0=1(OK), Node1=1(OK), Node2=2(OK), Node3=2(OK), Node4=2(OK). 
        # Total edits = 1 <= 4. Yes.
        {
            "n": 5, "k": 4,
            "edges": [(0,1), (2,3), (3,4), (4,2)],
            "caps": [1,1,2,2,2],
            "expected": 1
        },
        # Sample 3: 3 nodes, k=3, no edges. 
        # Components: 3. Edges needed: 2. 
        # Capacities: [1,1,1]. 
        # Max edges possible = 3 (triangle). 
        # Need 2 edges. k=3 >= 2. Yes? 
        # Wait, Sample Output 3 is "no". Why?
        # Capacities are all 1. A node with capacity 1 can only have degree 1.
        # To connect 3 nodes in a line (0-1-2), degrees are 1, 2, 1. 
        # Node 1 has degree 2, but capacity is 1. Invalid.
        # Triangle: degrees 2,2,2. All invalid.
        # Can't connect 3 nodes if all have capacity 1. So "no" is correct.
        {
            "n": 3, "k": 3,
            "edges": [],
            "caps": [1,1,1],
            "expected": 0
        },
        # Additional: Disconnected, but capacities full
        {
            "n": 4, "k": 1,
            "edges": [(0,1), (2,3)],
            "caps": [1,1,1,1],
            "expected": 0 # Need 1 edge to connect, but nodes 0,1,2,3 all degree 1 (full). Cannot add edge.
        }
    ]

    passed = 0
    failed = 0

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"--- Test Case {i+1}: n={tc['n']}, k={tc['k']}, edges={len(tc['edges'])} ---")
        
        try:
            # 1. Load n and k
            if has_signal(dut, 'n_in'):
                dut.n_in.value = clamp_to_width(tc['n'], DATA_WIDTH)
            if has_signal(dut, 'k_in'):
                dut.k_in.value = clamp_to_width(tc['k'], DATA_WIDTH)
            
            # 2. Load Capacities
            if has_signal(dut, 'deg_in'):
                # Handle array or individual signals
                for j in range(tc['n']):
                    cap = clamp_to_width(tc['caps'][j], DATA_WIDTH)
                    if has_signal(dut, f'deg_in_{j}'):
                        getattr(dut, f'deg_in_{j}').value = cap
                    else:
                        # Assume array indexing dut.deg_in[j]
                        dut.deg_in[j].value = cap
            
            # 3. Start loading edges
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Send edges
            if has_signal(dut, 'edge_valid_in'):
                for u, v in tc['edges']:
                    dut.edge_u_in.value = clamp_to_width(u, DATA_WIDTH)
                    dut.edge_v_in.value = clamp_to_width(v, DATA_WIDTH)
                    dut.edge_valid_in.value = 1
                    await RisingEdge(dut.clk)
                dut.edge_valid_in.value = 0
            
            # Wait for computation
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != tc['expected']:
                raise TestFailure(f"Expected {tc['expected']}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS")
            
            # Reset for next test
            await reset_dut(dut)

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            await reset_dut(dut)
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {passed+failed}")