import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_monochromatic_clique_sum(dut):
    """Test monochromatic clique sum computation"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        for j in range(8):
            dut.color_matrix[i][j].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=4, expected output 26
    dut.n.value = 4
    # Set color matrix (0-indexed)
    # Row 0: 0 1 1 1
    dut.color_matrix[0][0].value = 0
    dut.color_matrix[0][1].value = 1
    dut.color_matrix[0][2].value = 1
    dut.color_matrix[0][3].value = 1
    # Row 1: 1 0 2 2
    dut.color_matrix[1][0].value = 1
    dut.color_matrix[1][1].value = 0
    dut.color_matrix[1][2].value = 2
    dut.color_matrix[1][3].value = 2
    # Row 2: 1 2 0 3
    dut.color_matrix[2][0].value = 1
    dut.color_matrix[2][1].value = 2
    dut.color_matrix[2][2].value = 0
    dut.color_matrix[2][3].value = 3
    # Row 3: 1 2 3 0
    dut.color_matrix[3][0].value = 1
    dut.color_matrix[3][1].value = 2
    dut.color_matrix[3][2].value = 3
    dut.color_matrix[3][3].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max ~800 cycles for n=4 -> 15 subsets * ~50 cycles each)
    timeout = 2000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout waiting for done, timeout={timeout}")
    
    result = int(dut.result.value)
    expected = 26
    print(f"Test 1: Result={result}, Expected={expected}")
    if result != expected:
        raise TestFailure(f"Result mismatch: got {result}, expected {expected}")
    
    # Test case 2: n=5, all edges color 300, expected output 80
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 5
    for i in range(5):
        for j in range(5):
            if i == j:
                dut.color_matrix[i][j].value = 0
            else:
                dut.color_matrix[i][j].value = 300
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout waiting for done, timeout={timeout}")
    
    result = int(dut.result.value)
    expected = 80
    print(f"Test 2: Result={result}, Expected={expected}")
    if result != expected:
        raise TestFailure(f"Result mismatch: got {result}, expected {expected}")
    
    # Test case 3: n=1, single node, expected output 1
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 1
    dut.color_matrix[0][0].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout waiting for done, timeout={timeout}")
    
    result = int(dut.result.value)
    expected = 1
    print(f"Test 3: Result={result}, Expected={expected}")
    if result != expected:
        raise TestFailure(f"Result mismatch: got {result}, expected {expected}")
    
    print(f"All tests passed!")
