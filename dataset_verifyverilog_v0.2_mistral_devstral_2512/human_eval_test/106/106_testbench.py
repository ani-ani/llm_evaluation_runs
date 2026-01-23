import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_factorial_sum_sequence(dut):
    """Test factorial_sum_sequence module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: n=5 -> [1, 2, 6, 24, 15]
    dut.n.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected = [1, 2, 6, 24, 15]
    for i, exp in enumerate(expected):
        await RisingEdge(dut.clk)
        await Timer(1, units='ns')  # Small delay for signal propagation
        assert dut.valid.value == 1, f"Valid should be high for index {i}"
        assert dut.index.value == i, f"Index mismatch: expected {i}, got {dut.index.value}"
        assert dut.result.value == exp, f"Result mismatch at index {i}: expected {exp}, got {dut.result.value}"
    
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "Done should be high after all elements"
    assert dut.valid.value == 0, "Valid should be low when done"
    
    # Test 2: n=1 -> [1]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await RisingEdge(dut.clk)
    assert dut.valid.value == 1
    assert dut.result.value == 1
    assert dut.index.value == 0
    
    await RisingEdge(dut.clk)
    assert dut.done.value == 1
    
    # Test 3: n=3 -> [1, 2, 6]
    await RisingEdge(dut.clk)
    dut.n.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected_3 = [1, 2, 6]
    for i, exp in enumerate(expected_3):
        await RisingEdge(dut.clk)
        assert dut.valid.value == 1
        assert dut.result.value == exp
    
    await RisingEdge(dut.clk)
    assert dut.done.value == 1
    
    # Test 4: n=7 -> [1, 2, 6, 24, 15, 720, 28]
    await RisingEdge(dut.clk)
    dut.n.value = 7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    expected_7 = [1, 2, 6, 24, 15, 720, 28]
    for i, exp in enumerate(expected_7):
        await RisingEdge(dut.clk)
        assert dut.valid.value == 1, f"Valid low at index {i}"
        assert dut.result.value == exp, f"Index {i}: expected {exp}, got {dut.result.value}"
    
    await RisingEdge(dut.clk)
    assert dut.done.value == 1
    
    print(f"All tests passed!")