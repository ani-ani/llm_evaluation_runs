import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def set_input(dut, n_val, m_val):
    dut.n.value = clamp_to_width(n_val, 4)
    dut.m.value = clamp_to_width(m_val, 6)

async def set_edge(dut, a, b, idx, max_edges=32):
    if idx >= max_edges:
        raise TestFailure(f"Edge index {idx} exceeds max {max_edges}")
    dut.edge_a.value = clamp_to_width(a, 4)
    dut.edge_b.value = clamp_to_width(b, 4)
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_longest_path(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test case 1: 4 nodes, edges 1->2,2->3,2->4, longest path length 3
    await set_input(dut, 4, 3)
    for a,b in [(1,2), (2,3), (2,4)]:
        await set_edge(dut, a, b, 0)
        await set_edge(dut, a, b, 1)
        await set_edge(dut, a, b, 2)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    result = int(dut.result.value)
    if result != 3:
        raise TestFailure(f"Test 1 failed: expected 3, got {result}")
    
    # Test case 2: 7 nodes, longest path 6
    await reset_dut(dut)
    await set_input(dut, 7, 7)
    edges = [(1,2), (2,3), (3,4), (4,5), (5,2), (4,6), (5,7)]
    for i, (a,b) in enumerate(edges):
        await set_edge(dut, a, b, i)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    result = int(dut.result.value)
    if result != 6:
        raise TestFailure(f"Test 2 failed: expected 6, got {result}")
    
    # Additional test: empty graph
    await reset_dut(dut)
    await set_input(dut, 0, 0)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    result = int(dut.result.value)
    if result != 0:
        raise TestFailure(f"Test 3 failed: expected 0, got {result}")
    
    # Test with single node
    await reset_dut(dut)
    await set_input(dut, 1, 0)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    result = int(dut.result.value)
    if result != 1:
        raise TestFailure(f"Test 4 failed: expected 1, got {result}")