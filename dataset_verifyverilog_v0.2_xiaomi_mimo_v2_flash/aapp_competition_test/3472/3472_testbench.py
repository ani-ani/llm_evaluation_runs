import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_count_extra_lines(dut):
    """Test the count_extra_lines module with various inputs"""
    
    # Test case 1: 2 warlords, 1 line (not parallel - creates 2 regions)
    # 2 warlords need 2 regions, 1 line + 1 = 2 regions available
    # Output should be 0
    dut.warlords.value = 2
    dut.num_lines.value = 1
    dut.lines_parallel.value = 0
    await Timer(10, units='ns')
    
    result = int(dut.extra_lines.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"Test 1 failed: expected {expected}, got {result}")
    print(f"Test 1 passed: 2 warlords, 1 intersecting line -> {result} extra lines")
    
    # Test case 2: 5 warlords, 3 lines (not all parallel)
    # 3 lines + 1 = 4 regions available
    # Need 5 regions, so need 1 more line
    # Output should be 1
    dut.warlords.value = 5
    dut.num_lines.value = 3
    dut.lines_parallel.value = 0
    await Timer(10, units='ns')
    
    result = int(dut.extra_lines.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"Test 2 failed: expected {expected}, got {result}")
    print(f"Test 2 passed: 5 warlords, 3 intersecting lines -> {result} extra line")
    
    # Test case 3: 3 warlords, 2 parallel lines (creates 2 regions only)
    # Need 3 regions, so need 1 more line
    dut.warlords.value = 3
    dut.num_lines.value = 2
    dut.lines_parallel.value = 1
    await Timer(10, units='ns')
    
    result = int(dut.extra_lines.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"Test 3 failed: expected {expected}, got {result}")
    print(f"Test 3 passed: 3 warlords, 2 parallel lines -> {result} extra line")
    
    # Test case 4: 1 warlord, 0 lines
    # 0 lines = 1 region, need 1 region
    dut.warlords.value = 1
    dut.num_lines.value = 0
    dut.lines_parallel.value = 0
    await Timer(10, units='ns')
    
    result = int(dut.extra_lines.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"Test 4 failed: expected {expected}, got {result}")
    print(f"Test 4 passed: 1 warlord, 0 lines -> {result} extra lines")
    
    # Test case 5: 10 warlords, 5 intersecting lines (creates 6 regions)
    # Need 10 regions, so need 4 more lines
    dut.warlords.value = 10
    dut.num_lines.value = 5
    dut.lines_parallel.value = 0
    await Timer(10, units='ns')
    
    result = int(dut.extra_lines.value)
    expected = 4
    if result != expected:
        raise TestFailure(f"Test 5 failed: expected {expected}, got {result}")
    print(f"Test 5 passed: 10 warlords, 5 intersecting lines -> {result} extra lines")
    
    # Test case 6: 100 warlords, 99 intersecting lines (creates 100 regions)
    # Need 100 regions, so need 0 more lines
    dut.warlords.value = 100
    dut.num_lines.value = 99
    dut.lines_parallel.value = 0
    await Timer(10, units='ns')
    
    result = int(dut.extra_lines.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"Test 6 failed: expected {expected}, got {result}")
    print(f"Test 6 passed: 100 warlords, 99 intersecting lines -> {result} extra lines")
    
    print("All tests passed!")
