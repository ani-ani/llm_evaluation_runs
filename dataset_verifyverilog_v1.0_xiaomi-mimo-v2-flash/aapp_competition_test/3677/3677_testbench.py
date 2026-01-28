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

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_max_clique(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Simple triangle (3 nodes all connected)
    # Nodes: 0-1, 1-2, 2-0 all disagree
    dut.n_nodes.value = 3
    dut.max_k.value = 3
    
    # Set adjacency matrix (16x16, but only first 3x3 matters)
    for i in range(16):
        for j in range(16):
            # Row i, bit j
            if i < 3 and j < 3 and i != j:
                # All connected except self
                row_val = getattr(dut, f'adj_matrix_{i}').value
                row_val = int(row_val) | (1 << j)
                getattr(dut, f'adj_matrix_{i}').value = row_val
            else:
                # Clear
                getattr(dut, f'adj_matrix_{i}').value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    done = False
    for _ in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Test 1: Did not complete within 100 cycles")
    
    result = int(dut.result.value)
    if result != 3:
        raise TestFailure(f"Test 1: Expected 3, got {result}")
    
    cocotb.log.info("Test 1 passed: Triangle clique size = 3")
    
    # Test case 2: Two disconnected nodes
    # Reset first
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_nodes.value = 2
    dut.max_k.value = 2
    
    # Clear matrix
    for i in range(16):
        getattr(dut, f'adj_matrix_{i}').value = 0
    
    # No edges between 0 and 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Test 2: Did not complete")
    
    result = int(dut.result.value)
    # In a graph with no edges, max clique is 1 (single node)
    if result != 1:
        raise TestFailure(f"Test 2: Expected 1, got {result}")
    
    cocotb.log.info("Test 2 passed: Disconnected nodes clique size = 1")
    
    # Test case 3: Star graph (center connected to 3 leaves, leaves not connected)
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_nodes.value = 4
    dut.max_k.value = 4
    
    # Clear matrix
    for i in range(16):
        getattr(dut, f'adj_matrix_{i}').value = 0
    
    # Center node 0 connected to 1,2,3
    # Set bit j in row i if i and j connected
    for i in range(4):
        row_val = 0
        for j in range(4):
            if i == 0 and j > 0:  # center to leaves
                row_val |= (1 << j)
            elif j == 0 and i > 0:  # leaves to center
                row_val |= (1 << j)
        getattr(dut, f'adj_matrix_{i}').value = row_val
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
    
    if not done:
        raise TestFailure("Test 3: Did not complete")
    
    result = int(dut.result.value)
    # Star graph max clique is 2 (center + any leaf)
    if result != 2:
        raise TestFailure(f"Test 3: Expected 2, got {result}")
    
    cocotb.log.info("Test 3 passed: Star graph clique size = 2")
    
    cocotb.log.info("All tests passed!")
    
    # Check timeout
    if has_signal(dut, 'timeout') and int(dut.timeout.value) == 1:
        raise TestFailure("Design timed out")