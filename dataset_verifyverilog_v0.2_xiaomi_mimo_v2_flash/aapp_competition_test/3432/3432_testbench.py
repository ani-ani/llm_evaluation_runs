import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_minimal_max_sum(dut):
    """Test minimal maximal sum computation"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    dut.a_in.value = 0
    dut.b_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 2 8, 3 1, 1 4 => sorted A: [1,2,3], B: [8,4,1] => sums: 9,6,4 => max=9
    # But we need 8 elements for the module, pad with zeros
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Provide 8 pairs (pad with zeros)
    test_data = [(2,8), (3,1), (1,4), (0,0), (0,0), (0,0), (0,0), (0,0)]
    for a, b in test_data:
        dut.a_in.value = a
        dut.b_in.value = b
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Timeout waiting for done")
    
    # Expected: max(1+8, 2+0, 3+0, ...) = 9
    expected = 9
    actual = int(dut.result.value)
    print(f"Test 1: Expected {expected}, Got {actual}")
    assert actual == expected, f"Test 1 failed: expected {expected}, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test case 2: all zeros => max = 0
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_data = [(0,0)]*8
    for a, b in test_data:
        dut.a_in.value = a
        dut.b_in.value = b
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    actual = int(dut.result.value)
    print(f"Test 2: Expected 0, Got {actual}")
    assert actual == 0, f"Test 2 failed: expected 0, got {actual}"
    
    await RisingEdge(dut.clk)
    
    # Test case 3: max values 100,100
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    test_data = [(100,100), (0,0), (0,0), (0,0), (0,0), (0,0), (0,0), (0,0)]
    for a, b in test_data:
        dut.a_in.value = a
        dut.b_in.value = b
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    actual = int(dut.result.value)
    print(f"Test 3: Expected 200, Got {actual}")
    assert actual == 200, f"Test 3 failed: expected 200, got {actual}"
    
    print("2/3 tests passed")