import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_tuple_trimmer(dut):
    """Test tuple trimming functionality"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    dut.tuple_len.value = 0
    for i in range(4):
        setattr(dut, f'data_in_{i}', 0)
    
    await Timer(25, units='ns')
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: k=2, len=5, expecting 1 element per tuple
    dut._log.info("Test 1: k=2, len=5")
    dut.k.value = 2
    dut.tuple_len.value = 5
    dut.data_in_0.value = 5  # (5,3,2,1,4)
    dut.data_in_1.value = 3  # (3,4,9,2,1)
    dut.data_in_2.value = 9  # (9,1,2,3,5)
    dut.data_in_3.value = 4  # (4,8,2,1,7)
    # Note: In real implementation, we'd need individual element access
    # For this test, we'll verify the core logic works
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done signal
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 20:
        raise TestFailure("Test 1: Done signal not asserted within 20 cycles")
    
    # Check results - for k=2, tuple_len=5, result length = 1
    # Expected: each tuple trimmed to last element
    assert dut.out_len.value == 1, f"Expected out_len=1, got {dut.out_len.value}"
    
    # Verify first trimmed elements (last element of original tuples)
    assert dut.result_0.value == 2, f"Test 1 failed: result_0={dut.result_0.value}, expected 2"
    assert dut.result_1.value == 1, f"Test 1 failed: result_1={dut.result_1.value}, expected 1"
    assert dut.result_2.value == 5, f"Test 1 failed: result_2={dut.result_2.value}, expected 5"
    assert dut.result_3.value == 7, f"Test 1 failed: result_3={dut.result_3.value}, expected 7"
    
    dut._log.info("Test 1 passed")
    await RisingEdge(dut.clk)
    
    # Test 2: k=1, len=5, expecting 3 elements per tuple
    dut._log.info("Test 2: k=1, len=5")
    dut.k.value = 1
    dut.tuple_len.value = 5
    dut.data_in_0.value = 5
    dut.data_in_1.value = 3
    dut.data_in_2.value = 9
    dut.data_in_3.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 20:
        raise TestFailure("Test 2: Done signal not asserted within 20 cycles")
    
    # Expected: [(3,2,1), (4,9,2), (1,2,3), (8,2,1)]
    assert dut.out_len.value == 3, f"Test 2 failed: out_len={dut.out_len.value}, expected 3"
    # These would be the middle elements
    
    dut._log.info("Test 2 passed")
    await RisingEdge(dut.clk)
    
    # Test 3: k=1, len=4, expecting 2 elements per tuple
    dut._log.info("Test 3: k=1, len=4")
    dut.k.value = 1
    dut.tuple_len.value = 4
    dut.data_in_0.value = 7
    dut.data_in_1.value = 11
    dut.data_in_2.value = 4
    dut.data_in_3.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 20:
        raise TestFailure("Test 3: Done signal not asserted within 20 cycles")
    
    # Expected: [(8,4), (8,12), (1,7), (6,9)]
    assert dut.out_len.value == 2, f"Test 3 failed: out_len={dut.out_len.value}, expected 2"
    
    dut._log.info("Test 3 passed")
    await RisingEdge(dut.clk)
    
    # Test 4: Edge case - k=0, no trimming
    dut._log.info("Test 4: k=0, len=5")
    dut.k.value = 0
    dut.tuple_len.value = 5
    dut.data_in_0.value = 5
    dut.data_in_1.value = 3
    dut.data_in_2.value = 9
    dut.data_in_3.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 20:
        raise TestFailure("Test 4: Done signal not asserted within 20 cycles")
    
    assert dut.out_len.value == 5, f"Test 4 failed: out_len={dut.out_len.value}, expected 5"
    
    dut._log.info("Test 4 passed")
    await RisingEdge(dut.clk)
    
    # Test 5: Edge case - k=2, len=4, result length = 0
    dut._log.info("Test 5: k=2, len=4")
    dut.k.value = 2
    dut.tuple_len.value = 4
    dut.data_in_0.value = 7
    dut.data_in_1.value = 11
    dut.data_in_2.value = 4
    dut.data_in_3.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 20:
        raise TestFailure("Test 5: Done signal not asserted within 20 cycles")
    
    assert dut.out_len.value == 0, f"Test 5 failed: out_len={dut.out_len.value}, expected 0"
    
    dut._log.info("Test 5 passed")
    dut._log.info("All tests completed successfully")