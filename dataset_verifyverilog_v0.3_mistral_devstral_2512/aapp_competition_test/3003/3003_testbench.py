import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
MAX_VERTICES = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def run_test_case(dut, adjacency_matrix, expected):
    # Write adjacency matrix
    for i in range(MAX_VERTICES):
        port_name = f'adj_{i}'
        if has_signal(dut, port_name):
            row_val = 0
            for j in range(MAX_VERTICES):
                if adjacency_matrix[i][j]:
                    row_val |= (1 << j)
            getattr(dut, port_name).value = row_val
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    await wait_for_done(dut)
    
    # Verify
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.result.value)
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    dut._log.info(f"Test passed: result = {result}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_graph_coloring(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test case 1: 4 vertices, 3 colors needed
    # Graph: 0-1, 0-2, 1-2, 1-3
    adj1 = [
        [0,1,1,0,0,0,0,0],
        [1,0,1,1,0,0,0,0],
        [1,1,0,0,0,0,0,0],
        [0,1,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0]
    ]
    await run_test_case(dut, adj1, 3)
    
    # Test case 2: 5 vertices, bipartite, 2 colors
    adj2 = [
        [0,0,1,1,1,0,0,0],
        [0,0,1,1,1,0,0,0],
        [1,1,0,0,0,0,0,0],
        [1,1,0,0,0,0,0,0],
        [1,1,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0]
    ]
    await run_test_case(dut, adj2, 2)
    
    # Test case 3: 6 vertices, bipartite, 2 colors
    adj3 = [
        [0,1,0,1,0,0,0,0],
        [1,0,1,0,1,0,0,0],
        [0,1,0,0,0,1,0,0],
        [1,0,0,0,1,0,0,0],
        [0,1,0,1,0,1,0,0],
        [0,0,1,0,1,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0]
    ]
    await run_test_case(dut, adj3, 2)
    
    # Test case 4: 4 vertices, complete graph, 4 colors
    adj4 = [
        [0,1,1,1,0,0,0,0],
        [1,0,1,1,0,0,0,0],
        [1,1,0,1,0,0,0,0],
        [1,1,1,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0]
    ]
    await run_test_case(dut, adj4, 4)
    
    # Test case 5: 5 vertices, 3 colors needed
    adj5 = [
        [0,1,1,0,0,0,0,0],
        [1,0,1,1,0,0,0,0],
        [1,1,0,0,1,0,0,0],
        [0,1,0,0,1,0,0,0],
        [0,0,1,1,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0]
    ]
    await run_test_case(dut, adj5, 3)
    
    dut._log.info("All tests passed!")