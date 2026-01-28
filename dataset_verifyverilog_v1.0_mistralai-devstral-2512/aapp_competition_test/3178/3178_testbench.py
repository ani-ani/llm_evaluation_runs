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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_graph_decoration(dut):
    # Clock and reset
    clk = dut.clk
    rst_n = dut.rst_n
    cocotb.start_soon(Clock(clk, 10, units='ns').start())
    
    # Reset
    rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(clk)
    await RisingEdge(clk)
    rst_n.value = 1
    await RisingEdge(clk)
    
    # Test case 1: Sample 2 (N=6, M=5) -> expected 5
    dut.num_nodes.value = 6
    dut.num_edges.value = 5
    edges = [(1,4), (2,4), (0,4), (2,5), (0,5)]  # 0-indexed, converted from sample
    # In sample: 2-4, 3-5, 1-5, 3-6, 1-6 => 0-index: 1-3, 2-4, 0-4, 2-5, 0-5
    edges = [(1,3), (2,4), (0,4), (2,5), (0,5)]
    
    # Set edge inputs - assuming graph_edges is an array of ports
    # For simplicity, assume graph_edges_u[0:4] and graph_edges_v[0:4]
    for i in range(5):
        getattr(dut, f'graph_edges_u_{i}').value = edges[i][0]
        getattr(dut, f'graph_edges_v_{i}').value = edges[i][1]
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(clk)
    dut.start.value = 0
    
    # Wait for done
    done = False
    for _ in range(10000):
        await RisingEdge(clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Timeout: done not asserted")
    
    # Check result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.result.value)
    # Convert signed 16-bit if needed
    if result >= 32768:  # MSB set
        result = result - 65536
    
    if result != 5:
        raise TestFailure(f"Expected 5, got {result}")
    
    # Test case 2: Sample 1 (N=5, M=8) -> expected -1
    await RisingEdge(clk)
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(clk)
    await RisingEdge(clk)
    dut.rst_n.value = 1
    await RisingEdge(clk)
    
    dut.num_nodes.value = 5
    dut.num_edges.value = 8
    # Edges: 1-4,4-5,1-5,1-2,1-3,2-3,3-5,2-5 => 0-index: 0-3,3-4,0-4,0-1,0-2,1-2,2-4,1-4
    edges = [(0,3),(3,4),(0,4),(0,1),(0,2),(1,2),(2,4),(1,4)]
    for i in range(8):
        getattr(dut, f'graph_edges_u_{i}').value = edges[i][0]
        getattr(dut, f'graph_edges_v_{i}').value = edges[i][1]
    
    dut.start.value = 1
    await RisingEdge(clk)
    dut.start.value = 0
    
    done = False
    for _ in range(10000):
        await RisingEdge(clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Timeout for second test")
    
    result = int(dut.result.value)
    if result >= 32768:
        result = result - 65536
    
    if result != -1:
        raise TestFailure(f"Expected -1, got {result}")
    
    # Test case 3: Sample 3 (N=10, M=10) -> expected 5
    # Note: N=10 exceeds our scaled N<=8, so we expect it to handle or output -1.
    # For this test, we assume the module scales or handles up to 16 nodes.
    # If the module is designed for N<=8, this test might fail, but we include it for completeness.
    await RisingEdge(clk)
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(clk)
    await RisingEdge(clk)
    dut.rst_n.value = 1
    await RisingEdge(clk)
    
    dut.num_nodes.value = 10
    dut.num_edges.value = 10
    # Edges from sample: 5-8,2-6,3-9,1-4,9-10,4-6,5-9,7-8,7-10,2-3 => 0-index: 4-7,1-5,2-8,0-3,8-9,3-5,4-8,6-7,6-9,1-2
    edges = [(4,7),(1,5),(2,8),(0,3),(8,9),(3,5),(4,8),(6,7),(6,9),(1,2)]
    for i in range(10):
        getattr(dut, f'graph_edges_u_{i}').value = edges[i][0]
        getattr(dut, f'graph_edges_v_{i}').value = edges[i][1]
    
    dut.start.value = 1
    await RisingEdge(clk)
    dut.start.value = 0
    
    done = False
    for _ in range(10000):
        await RisingEdge(clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Timeout for third test")
    
    result = int(dut.result.value)
    if result >= 32768:
        result = result - 65536
    
    # Since N=10 > 8, if module is for N<=8, result might be -1 or something else.
    # But example says 5, so we check for 5. If your module is limited, adjust expectation.
    if result != 5:
        raise TestFailure(f"Expected 5 for third test, got {result}")