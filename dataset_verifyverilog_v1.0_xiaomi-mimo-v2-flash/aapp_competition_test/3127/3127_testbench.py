import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Scaling constants
MAX_NODES = 16
MAX_EDGES = 32
DATA_WIDTH = 32
CLK_NS = 10

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_graph(dut, n, m, edges):
    """Load graph data into the DUT. Assumes inputs are arrays or distinct ports."""
    dut.num_nodes.value = n
    dut.src_id.value = 1 # Always source 1 in problem
    dut.dest_id.value = n # Always dest n in problem
    dut.edge_count.value = m
    
    # Handle edge inputs: assuming port naming edge_a[i], edge_b[i], edge_len[i]
    # or packed vectors. Using individual ports for robustness.
    for i in range(m):
        a, b, l = edges[i]
        if has_signal(dut, f'edge_a_{i}'):
            getattr(dut, f'edge_a_{i}').value = a
            getattr(dut, f'edge_b_{i}').value = b
            getattr(dut, f'edge_len_{i}').value = l
        elif has_signal(dut, 'edge_a'):
            # Array of signals
            dut.edge_a[i].value = a
            dut.edge_b[i].value = b
            dut.edge_len[i].value = l
        else:
            # Packed signal fallback (unlikely for 32x4 bits)
            pass

async def wait_for_done(dut, max_cycles=2048):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_network(dut):
    # Setup Clock
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Test Case 1: Sample 1
    # 7 nodes, 8 edges
    # Expected unused: 4, 6 (Output bits: node 4 and 6 set to 1)
    edges1 = [
        (1, 2, 2), (1, 3, 1), (1, 4, 3),
        (2, 6, 1), (2, 7, 2), (3, 5, 1),
        (4, 7, 2), (5, 7, 1)
    ]
    # Expected result: Bit 3 (node 4) and Bit 5 (node 6) set.
    # Result is 16-bit. Expected value: 00100100...0 = 0x24 (if LSB is node 1)
    # Wait, indices are 1-based. Node 4 -> bit 3. Node 6 -> bit 5.
    expected1 = (1 << 3) | (1 << 5)

    await load_graph(dut, 7, 8, edges1)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result1 = int(dut.result.value)
    # Check bits
    if result1 != expected1:
        # Detailed logging
        cocotb.log.info(f"Test 1: Expected binary {bin(expected1)}, got {bin(result1)}")
        raise TestFailure(f"Test 1 failed. Expected {expected1}, got {result1}")

    await reset_dut(dut)

    # Test Case 2: Sample 2
    # 5 nodes, 6 edges
    # Expected unused: None
    edges2 = [
        (1, 2, 2), (2, 3, 2), (3, 5, 2),
        (1, 4, 3), (4, 5, 3), (1, 5, 6)
    ]
    expected2 = 0

    await load_graph(dut, 5, 6, edges2)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result2 = int(dut.result.value)
    if result2 != expected2:
        raise TestFailure(f"Test 2 failed. Expected {expected2}, got {result2}")
