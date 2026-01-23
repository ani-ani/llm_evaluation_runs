import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_critical_elements_basic(dut):
    """Test basic critical element detection"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: n=4, seq=[1,3,2,4] -> critical = [1,4] (bits 0,3 set)
    # Original LIS: [1,3,4] or [1,2,4] = length 3
    # Remove pos0(1): [3,2,4] LIS=2 -> critical
    # Remove pos1(3): [1,2,4] LIS=3 -> not critical
    # Remove pos2(2): [1,3,4] LIS=3 -> not critical  
    # Remove pos3(4): [1,3,2] LIS=2 -> critical
    dut.n.value = 4
    dut.seq[0].value = 1
    dut.seq[1].value = 3
    dut.seq[2].value = 2
    dut.seq[3].value = 4
    dut.seq[4].value = 0
    dut.seq[5].value = 0
    dut.seq[6].value = 0
    dut.seq[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 10 cycles)
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Done not asserted within 15 cycles")
    
    # Expected: critical_mask = 0b1001 = 0x09
    expected_mask = 0x09
    actual_mask = int(dut.critical_mask.value)
    
    if actual_mask != expected_mask:
        raise TestFailure(f"Test 1 failed: expected 0x{expected_mask:02X}, got 0x{actual_mask:02X}")
    
    print(f"Test 1 passed: seq=[1,3,2,4], critical_mask=0x{actual_mask:02X}")

@cocotb.test()
async def test_critical_elements_all(dut):
    """Test case where all elements are critical"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: n=5, seq=[1,2,3,4,5] -> all critical
    # Any removal reduces LIS from 5 to 4
    dut.n.value = 5
    dut.seq[0].value = 1
    dut.seq[1].value = 2
    dut.seq[2].value = 3
    dut.seq[3].value = 4
    dut.seq[4].value = 5
    dut.seq[5].value = 0
    dut.seq[6].value = 0
    dut.seq[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: Done not asserted")
    
    # Expected: critical_mask = 0b11111 = 0x1F
    expected_mask = 0x1F
    actual_mask = int(dut.critical_mask.value)
    
    if actual_mask != expected_mask:
        raise TestFailure(f"Test 2 failed: expected 0x{expected_mask:02X}, got 0x{actual_mask:02X}")
    
    print(f"Test 2 passed: seq=[1,2,3,4,5], critical_mask=0x{actual_mask:02X}")

@cocotb.test()
async def test_critical_elements_none(dut):
    """Test case where no elements are critical"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: n=4, seq=[2,1,4,3] -> no critical
    # Original LIS: [2,4] or [1,3] or [2,3] = length 2
    # Any removal: LIS still 2
    dut.n.value = 4
    dut.seq[0].value = 2
    dut.seq[1].value = 1
    dut.seq[2].value = 4
    dut.seq[3].value = 3
    dut.seq[4].value = 0
    dut.seq[5].value = 0
    dut.seq[6].value = 0
    dut.seq[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: Done not asserted")
    
    # Expected: critical_mask = 0 (no elements)
    expected_mask = 0
    actual_mask = int(dut.critical_mask.value)
    
    if actual_mask != expected_mask:
        raise TestFailure(f"Test 3 failed: expected 0x{expected_mask:02X}, got 0x{actual_mask:02X}")
    
    print(f"Test 3 passed: seq=[2,1,4,3], critical_mask=0x{actual_mask:02X}")

@cocotb.test()
async def test_critical_elements_case4(dut):
    """Test case 4: n=4, seq=[4,3,1,2] -> critical = [1,2] (bits 2,3 set)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 4
    dut.seq[0].value = 4
    dut.seq[1].value = 3
    dut.seq[2].value = 1
    dut.seq[3].value = 2
    dut.seq[4].value = 0
    dut.seq[5].value = 0
    dut.seq[6].value = 0
    dut.seq[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 4: Done not asserted")
    
    # Expected: critical_mask = 0b1100 = 0x0C (positions 2,3 which are 1,2 in value)
    expected_mask = 0x0C
    actual_mask = int(dut.critical_mask.value)
    
    if actual_mask != expected_mask:
        raise TestFailure(f"Test 4 failed: expected 0x{expected_mask:02X}, got 0x{actual_mask:02X}")
    
    print(f"Test 4 passed: seq=[4,3,1,2], critical_mask=0x{actual_mask:02X}")

@cocotb.test()
async def test_error_case(dut):
    """Test error handling for n < 2"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 1
    dut.seq[0].value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await RisingEdge(dut.clk)
    
    if dut.error.value != 1:
        raise TestFailure("Test 5: Error flag not set for n=1")
    
    if dut.done.value != 1:
        raise TestFailure("Test 5: Done not set on error")
    
    print("Test 5 passed: Error handling correct")
    
    print("
All tests passed!")