import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

# Testbench Configuration
CLK_NS = 10
MAX_CYCLES = 5000

def pack_edge(a, b, cost):
    # 32-bit: cost[15:0], a[7:0], b[7:0]
    return (cost & 0xFFFF) | ((a & 0xFF) << 16) | ((b & 0xFF) << 24)

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_mst_special(dut):
    # Setup clock if present
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational, just wait a bit
        await Timer(100, units='ns')

    # Test Case 1: Example from prompt
    # 3 nodes, 3 edges, 1 special (node 2), w=2
    # Edges: 1-2 (2), 1-3 (1), 2-3 (3)
    # Need spanning tree with 2 special-nonspecial edges.
    # Tree 1-2-3: edges (1-2, 2-3). Special node 2 connects to 1 and 3. w=2. Cost=2+3=5.
    # Tree 1-3-2: edges (1-3, 2-3). Special node 2 connects to 3 only. w=1. Cost=1+3=4.
    # We need w=2, so we must pick Tree 1-2-3. Cost=5.
    
    n, m, k, w = 3, 3, 1, 2
    edges = [
        (1, 2, 2),
        (1, 3, 1),
        (2, 3, 3)
    ]
    specials = [2]

    # Configure inputs
    dut.edge_count.value = m
    dut.target_w.value = w
    
    # Special mask (bit 0 = node 1, bit 1 = node 2...)
    mask = 0
    for s in specials:
        mask |= 1 << (s - 1)
    dut.special_mask.value = mask

    # Feed edges sequentially if there's an edge_in port
    if has_signal(dut, 'edge_in'):
        for a, b, c in edges:
            dut.edge_in.value = pack_edge(a, b, c)
            await RisingEdge(dut.clk) # Assuming handshake or buffer full
    else:
        # If parallel ports exist, map them
        # Assuming arr_a, arr_b, arr_c for simplicity if not packed
        pass

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    await wait_for_done(dut)

    # Check result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result signal undefined")
    
    result = int(dut.result.value)
    expected = 5
    
    # Handle signed -1
    if result >= (1 << 15): # Assuming 16-bit result, MSB is sign
        result = result - (1 << 16)
        
    if result != expected:
        raise TestFailure(f"Test 1 Failed: Expected {expected}, got {result}")
    
    cocotb.log.info("Test 1 Passed")

    # --- Test Case 2: Impossible ---
    # 3 nodes, 1 edge, 1 special, w=1
    # Edge 1-2 (2). Graph not connected. Should output -1.
    
    await reset_dut(dut)
    
    n, m, k, w = 3, 1, 1, 1
    edges = [(1, 2, 2)]
    specials = [2]
    
    dut.edge_count.value = m
    dut.target_w.value = w
    mask = 0
    for s in specials:
        mask |= 1 << (s - 1)
    dut.special_mask.value = mask

    if has_signal(dut, 'edge_in'):
        for a, b, c in edges:
            dut.edge_in.value = pack_edge(a, b, c)
            await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    await wait_for_done(dut)

    if not is_value_defined(dut.result.value):
        raise TestFailure("Result signal undefined")
        
    result = int(dut.result.value)
    if result >= (1 << 15):
        result = result - (1 << 16)
    
    expected = -1
    if result != expected:
        raise TestFailure(f"Test 2 Failed: Expected {expected}, got {result}")
        
    cocotb.log.info("Test 2 Passed")
