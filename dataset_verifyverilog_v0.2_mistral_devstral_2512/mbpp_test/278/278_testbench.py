import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_count_first_elements(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_types.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: (1,5,7,(4,6),10) → scalars at indices 0-2, tuple at 3
    # Expected: 3 scalars before tuple
    dut.data_types.value = 0b00_00_00_01_00_00_00_00  # index 3 is tuple
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for processing (max 8 cycles + done)
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.result.value == 3, f"Test 1 failed: expected 3, got {int(dut.result.value)}"
    assert dut.done.value == 1, "Test 1: done not asserted"
    print("Test 1 passed: 3 scalars before tuple")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: (2,9,(5,7),11) → scalars at 0-1, tuple at 2
    # Expected: 2 scalars before tuple
    dut.data_types.value = 0b00_00_01_00_00_00_00_00  # index 2 is tuple
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.result.value == 2, f"Test 2 failed: expected 2, got {int(dut.result.value)}"
    assert dut.done.value == 1, "Test 2: done not asserted"
    print("Test 2 passed: 2 scalars before tuple")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: (11,15,5,8,(2,3),8) → scalars at 0-3, tuple at 4
    # Expected: 4 scalars before tuple
    dut.data_types.value = 0b00_00_00_00_01_00_00_00  # index 4 is tuple
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.result.value == 4, f"Test 3 failed: expected 4, got {int(dut.result.value)}"
    assert dut.done.value == 1, "Test 3: done not asserted"
    print("Test 3 passed: 4 scalars before tuple")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 4: All scalars, no tuple
    # Expected: 8 (all scalars)
    dut.data_types.value = 0b00_00_00_00_00_00_00_00  # all scalars
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.result.value == 8, f"Test 4 failed: expected 8, got {int(dut.result.value)}"
    assert dut.done.value == 1, "Test 4: done not asserted"
    print("Test 4 passed: 8 scalars before tuple")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 5: Tuple at first element
    # Expected: 0 (no scalars before tuple)
    dut.data_types.value = 0b00_00_00_00_00_00_00_01  # index 0 is tuple
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.result.value == 0, f"Test 5 failed: expected 0, got {int(dut.result.value)}"
    assert dut.done.value == 1, "Test 5: done not asserted"
    print("Test 5 passed: 0 scalars before tuple")
    
    print("
All tests passed: 5/5")