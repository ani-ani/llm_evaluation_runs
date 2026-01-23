import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_monotonic_basic(dut):
    """Test basic monotonic sequences"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.length.value = 0
    for i in range(8):
        dut.data[i].value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([1, 2, 4, 10], 1, 4),  # Increasing
        ([1, 2, 4, 20], 1, 4),  # Increasing
        ([1, 20, 4, 10], 0, 4), # Not monotonic
        ([4, 1, 0, -10], 1, 4), # Decreasing
        ([4, 1, 1, 0], 1, 4),   # Decreasing with equal
        ([1, 2, 3, 2, 5, 60], 0, 6), # Not monotonic
        ([1, 2, 3, 4, 5, 60], 1, 6), # Increasing
        ([9, 9, 9, 9], 1, 4),   # All equal
        ([5], 1, 1),            # Single element
        ([], 1, 0),             # Empty
        ([1, 2, 3], 1, 3),      # 3 elements increasing
        ([3, 2, 1], 1, 3),      # 3 elements decreasing
        ([1, 2, 2, 2, 3], 1, 5), # Mixed equal/increasing
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr, expected, length in test_cases:
        # Load array
        for i in range(8):
            if i < length:
                dut.data[i].value = arr[i] & 0xFF
            else:
                dut.data[i].value = 0
        
        dut.length.value = length
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 10 cycles)
        timeout = 15
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if dut.done.value != 1:
            raise TestFailure(f"Test case {arr}: done not asserted within timeout")
        
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Test case {arr}: expected {expected}, got {actual}")
        
        passed += 1
    
    dut._log.info(f"{passed}/{total} tests passed")

@cocotb.test()
async def test_monotonic_edge_cases(dut):
    """Test edge cases and boundary values"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    edge_cases = [
        ([255, 254, 253], 1, 3),  # Max values decreasing
        ([0, 1, 2, 3], 1, 4),     # Min values increasing
        ([127, 127, 127], 1, 3),  # Mid-point equal
        ([1, 2, 1], 0, 3),        # Peaked
        ([2, 1, 2], 0, 3),        # Valleyed
        ([0, 0, 0, 0, 0], 1, 5),  # All zeros
    ]
    
    passed = 0
    total = len(edge_cases)
    
    for arr, expected, length in edge_cases:
        for i in range(8):
            if i < length:
                dut.data[i].value = arr[i] & 0xFF
            else:
                dut.data[i].value = 0
        
        dut.length.value = length
        await RisingEdge(dut.clk)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for _ in range(15):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Edge case {arr}: expected {expected}, got {actual}")
        
        passed += 1
    
    dut._log.info(f"{passed}/{total} edge case tests passed")