import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_unique_digits(dut):
    """Test unique_digits module with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.in0.value = 0
    dut.in1.value = 0
    dut.in2.value = 0
    dut.in3.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [15, 33, 1422, 1] -> [1, 15, 33]
    print("
Test 1: [15, 33, 1422, 1]")
    dut.in0.value = 15
    dut.in1.value = 33
    dut.in2.value = 1422
    dut.in3.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 200 cycles)
    timeout = 0
    while dut.done.value == 0 and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 200, "Timeout - computation took too long"
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.count.value == 3, f"Expected count=3, got {dut.count.value}"
    assert dut.out0.value == 1, f"out0: expected 1, got {dut.out0.value}"
    assert dut.out1.value == 15, f"out1: expected 15, got {dut.out1.value}"
    assert dut.out2.value == 33, f"out2: expected 33, got {dut.out2.value}"
    print(f"  Result: [{dut.out0.value}, {dut.out1.value}, {dut.out2.value}] (count={dut.count.value})")
    print("  PASSED")
    
    # Reset for next test
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: [152, 323, 1422, 10] -> []
    print("
Test 2: [152, 323, 1422, 10]")
    dut.in0.value = 152
    dut.in1.value = 323
    dut.in2.value = 1422
    dut.in3.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 200, "Timeout - computation took too long"
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.count.value == 0, f"Expected count=0, got {dut.count.value}"
    print(f"  Result: [] (count={dut.count.value})")
    print("  PASSED")
    
    # Reset for next test
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: [12345, 2033, 111, 151] -> [111, 151]
    print("
Test 3: [12345, 2033, 111, 151]")
    dut.in0.value = 12345
    dut.in1.value = 2033
    dut.in2.value = 111
    dut.in3.value = 151
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 200, "Timeout - computation took too long"
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.count.value == 2, f"Expected count=2, got {dut.count.value}"
    assert dut.out0.value == 111, f"out0: expected 111, got {dut.out0.value}"
    assert dut.out1.value == 151, f"out1: expected 151, got {dut.out1.value}"
    print(f"  Result: [{dut.out0.value}, {dut.out1.value}] (count={dut.count.value})")
    print("  PASSED")
    
    # Reset for next test
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 4: [135, 103, 31] -> [31, 135]
    print("
Test 4: [135, 103, 31]")
    dut.in0.value = 135
    dut.in1.value = 103
    dut.in2.value = 31
    dut.in3.value = 0  # Unused
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 200, "Timeout - computation took too long"
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.count.value == 2, f"Expected count=2, got {dut.count.value}"
    assert dut.out0.value == 31, f"out0: expected 31, got {dut.out0.value}"
    assert dut.out1.value == 135, f"out1: expected 135, got {dut.out1.value}"
    print(f"  Result: [{dut.out0.value}, {dut.out1.value}] (count={dut.count.value})")
    print("  PASSED")
    
    # Edge case: empty-ish (all zeros)
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
Test 5: [2, 4, 6, 8] -> []")
    dut.in0.value = 2
    dut.in1.value = 4
    dut.in2.value = 6
    dut.in3.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 200, "Timeout - computation took too long"
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.count.value == 0, f"Expected count=0, got {dut.count.value}"
    print(f"  Result: [] (count={dut.count.value})")
    print("  PASSED")
    
    print("
=== All 5 tests passed ===")
