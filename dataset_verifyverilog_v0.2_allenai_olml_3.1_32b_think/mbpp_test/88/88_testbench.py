import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_freq_counter(dut):
    """Test frequency counter module"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Freq Counter Test Suite ===")
    
    # Test Case 1: Original test case 1 (adapted)
    print("
Test 1: [10,10,10,10,20,20,20,20,40,40,50,50,30,255,255,255]")
    dut.list_data[0].value = 10
    dut.list_data[1].value = 10
    dut.list_data[2].value = 10
    dut.list_data[3].value = 10
    dut.list_data[4].value = 20
    dut.list_data[5].value = 20
    dut.list_data[6].value = 20
    dut.list_data[7].value = 20
    dut.list_data[8].value = 40
    dut.list_data[9].value = 40
    dut.list_data[10].value = 50
    dut.list_data[11].value = 50
    dut.list_data[12].value = 30
    dut.list_data[13].value = 255
    dut.list_data[14].value = 255
    dut.list_data[15].value = 255
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal not asserted"
    
    # Check results - frequency counts should match
    # Expected: 10:4, 20:4, 40:2, 50:2, 30:1
    freq_map = {}
    for i in range(int(dut.unique_count.value)):
        val = int(dut.unique_values[i].value)
        freq = int(dut.frequencies[i].value)
        freq_map[val] = freq
    
    print(f"Unique count: {dut.unique_count.value}")
    print(f"Frequency map: {freq_map}")
    
    assert freq_map.get(10) == 4, f"10 should have freq 4, got {freq_map.get(10)}"
    assert freq_map.get(20) == 4, f"20 should have freq 4, got {freq_map.get(20)}"
    assert freq_map.get(40) == 2, f"40 should have freq 2, got {freq_map.get(40)}"
    assert freq_map.get(50) == 2, f"50 should have freq 2, got {freq_map.get(50)}"
    assert freq_map.get(30) == 1, f"30 should have freq 1, got {freq_map.get(30)}"
    
    print("Test 1: PASSED")
    
    # Test Case 2: Original test case 2 (adapted)
    print("
Test 2: [1,2,3,4,3,2,4,1,3,1,4,255,255,255,255,255]")
    test2 = [1,2,3,4,3,2,4,1,3,1,4,255,255,255,255,255]
    for i, val in enumerate(test2):
        dut.list_data[i].value = val
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    freq_map = {}
    for i in range(int(dut.unique_count.value)):
        val = int(dut.unique_values[i].value)
        freq = int(dut.frequencies[i].value)
        freq_map[val] = freq
    
    print(f"Frequency map: {freq_map}")
    assert freq_map.get(1) == 3, f"1 should have freq 3, got {freq_map.get(1)}"
    assert freq_map.get(2) == 2, f"2 should have freq 2, got {freq_map.get(2)}"
    assert freq_map.get(3) == 3, f"3 should have freq 3, got {freq_map.get(3)}"
    assert freq_map.get(4) == 3, f"4 should have freq 3, got {freq_map.get(4)}"
    print("Test 2: PASSED")
    
    # Test Case 3: Original test case 3 (adapted)
    print("
Test 3: [5,6,7,4,9,10,4,5,6,7,9,5,255,255,255,255]")
    test3 = [5,6,7,4,9,10,4,5,6,7,9,5,255,255,255,255]
    for i, val in enumerate(test3):
        dut.list_data[i].value = val
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    freq_map = {}
    for i in range(int(dut.unique_count.value)):
        val = int(dut.unique_values[i].value)
        freq = int(dut.frequencies[i].value)
        freq_map[val] = freq
    
    print(f"Frequency map: {freq_map}")
    assert freq_map.get(5) == 3, f"5 should have freq 3, got {freq_map.get(5)}"
    assert freq_map.get(6) == 2, f"6 should have freq 2, got {freq_map.get(6)}"
    assert freq_map.get(7) == 2, f"7 should have freq 2, got {freq_map.get(7)}"
    assert freq_map.get(4) == 2, f"4 should have freq 2, got {freq_map.get(4)}"
    assert freq_map.get(9) == 2, f"9 should have freq 2, got {freq_map.get(9)}"
    assert freq_map.get(10) == 1, f"10 should have freq 1, got {freq_map.get(10)}"
    print("Test 3: PASSED")
    
    # Test Case 4: All same values
    print("
Test 4: All same (all 42s)")
    for i in range(16):
        dut.list_data[i].value = 42
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert int(dut.unique_count.value) == 1, "Should find 1 unique value"
    assert int(dut.unique_values[0].value) == 42, "Unique value should be 42"
    assert int(dut.frequencies[0].value) == 16, "Frequency should be 16"
    print("Test 4: PASSED")
    
    # Test Case 5: All different (limited to 8 unique)
    print("
Test 5: Many different values (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16)")
    for i in range(16):
        dut.list_data[i].value = i + 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    unique_count = int(dut.unique_count.value)
    print(f"Unique count: {unique_count}")
    assert unique_count == 8, f"Should find 8 unique values (array limit), got {unique_count}"
    for i in range(8):
        assert int(dut.frequencies[i].value) == 2, f"Value {dut.unique_values[i].value} should have freq 2"
    print("Test 5: PASSED")
    
    print(f"
=== All tests passed! ===")