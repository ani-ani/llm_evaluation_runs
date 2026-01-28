import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
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

async def write_edges(dut, edges_u, edges_v, edges_c, edges_w, num_edges):
    # Write edge data into the input arrays
    # We assume the DUT has flat arrays or named ports like edges_u_0, edges_u_1...
    # Check for packed array or individual signals
    
    if hasattr(dut, 'edges_u'):
        # Assuming hierarchical array
        for i in range(num_edges):
            dut.edges_u[i].value = clamp_to_width(edges_u[i], 4)
            dut.edges_v[i].value = clamp_to_width(edges_v[i], 4)
            dut.edges_c[i].value = clamp_to_width(edges_c[i], 8)
            dut.edges_w[i].value = clamp_to_width(edges_w[i], 8)
    else:
        # Try individual signals edges_u_0, edges_u_1...
        for i in range(num_edges):
            getattr(dut, f'edges_u_{i}').value = clamp_to_width(edges_u[i], 4)
            getattr(dut, f'edges_v_{i}').value = clamp_to_width(edges_v[i], 4)
            getattr(dut, f'edges_c_{i}').value = clamp_to_width(edges_c[i], 8)
            getattr(dut, f'edges_w_{i}').value = clamp_to_width(edges_w[i], 8)

@cocotb.test(timeout_time=20000, timeout_unit="ms")
async def test_min_cost_flow(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic fallback
        await Timer(100, units='ns')

    # Test Case 1: Sample 1
    # 4 4 0 3
    # 0 1 4 10
    # 1 2 2 10
    # 0 2 4 30
    # 2 3 4 10
    # Output: 4 140
    
    dut.num_nodes.value = 4
    dut.s.value = 0
    dut.t.value = 3
    
    edges_u = [0, 1, 0, 2]
    edges_v = [1, 2, 2, 3]
    edges_c = [4, 2, 4, 4]
    edges_w = [10, 10, 30, 10]
    num_edges = 4
    
    dut.num_edges.value = num_edges
    await write_edges(dut, edges_u, edges_v, edges_c, edges_w, num_edges)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
        
    if not is_value_defined(dut.max_flow.value) or not is_value_defined(dut.min_cost.value):
        raise TestFailure("Result signals undefined")
        
    flow = int(dut.max_flow.value)
    cost = int(dut.min_cost.value)
    
    if flow != 4:
        raise TestFailure(f"Test 1 Failed: Expected flow 4, got {flow}")
    if cost != 140:
        raise TestFailure(f"Test 1 Failed: Expected cost 140, got {cost}")
        
    cocotb.log.info(f"Test 1 Passed: Flow={flow}, Cost={cost}")
    
    # Test Case 2: Sample 2
    # 2 1 0 1
    # 0 1 1000 100
    # Output: 1000 100000
    
    # Reset again
    await reset_dut(dut)
    
    dut.num_nodes.value = 2
    dut.s.value = 0
    dut.t.value = 1
    
    edges_u = [0]
    edges_v = [1]
    edges_c = [255] # Clamp 1000 to 255 (8-bit)
    edges_w = [100]
    num_edges = 1
    
    dut.num_edges.value = num_edges
    await write_edges(dut, edges_u, edges_v, edges_c, edges_w, num_edges)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')

    flow = int(dut.max_flow.value)
    cost = int(dut.min_cost.value)
    
    # Expected clamped flow: 255 * 100 = 25500
    # Expected clamped cost: 25500
    expected_flow = 255
    expected_cost = 25500
    
    if flow != expected_flow:
        raise TestFailure(f"Test 2 Failed: Expected flow {expected_flow}, got {flow}")
    if cost != expected_cost:
        raise TestFailure(f"Test 2 Failed: Expected cost {expected_cost}, got {cost}")
        
    cocotb.log.info(f"Test 2 Passed: Flow={flow}, Cost={cost}")

@cocotb.test(timeout_time=20000, timeout_unit="ms")
async def test_no_path(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test Case 3: No path (t > n-1 effectively or disconnected)
    # 2 1 1 0 (Source 1, Sink 0, Edge 0->1)
    # Output: 0 0
    
    dut.num_nodes.value = 2
    dut.s.value = 1
    dut.t.value = 0
    
    edges_u = [0]
    edges_v = [1]
    edges_c = [255]
    edges_w = [100]
    num_edges = 1
    
    dut.num_edges.value = num_edges
    await write_edges(dut, edges_u, edges_v, edges_c, edges_w, num_edges)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
        
    flow = int(dut.max_flow.value)
    cost = int(dut.min_cost.value)
    
    if flow != 0:
        raise TestFailure(f"Test 3 Failed: Expected flow 0, got {flow}")
    if cost != 0:
        raise TestFailure(f"Test 3 Failed: Expected cost 0, got {cost}")
        
    cocotb.log.info(f"Test 3 Passed: Flow={flow}, Cost={cost}")
