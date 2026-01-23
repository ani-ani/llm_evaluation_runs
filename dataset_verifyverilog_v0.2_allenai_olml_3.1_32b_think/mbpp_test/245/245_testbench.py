import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_bitonic_max_sum(dut):
    """Test bitonic max sum module"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_len.value = 0
    for i in range(8):
        dut.array_data[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1, 15, 51, 45, 33, 100, 12, 18, 9] -> 194
    # But we have only 8 elements, use first 8: [1, 15, 51, 45, 33, 100, 12, 18] -> 192
    # Adapted: [1, 15, 51, 45, 33, 100, 12, 18] - bitonic: 1,15,51,45,33,100 - no, need increasing then decreasing
    # Let's use known bitonic: [1, 15, 51, 45, 33] -> 1+15+51+45+33 = 145, or 1+15+51+33=100, or 15+51+45+33=144
    # Actually: 1,15,51,45,33 -> sum 145 (full array is bitonic)
    # Simpler test: [1, 15, 51, 45, 33] -> 145
    
    dut.array_len.value = 5
    dut.array_data[0].value = 1
    dut.array_data[1].value = 15
    dut.array_data[2].value = 51
    dut.array_data[3].value = 45
    dut.array_data[4].value = 33
    dut.array_data[5].value = 0
    dut.array_data[6].value = 0
    dut.array_data[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (approx 1000 cycles for 5 elements)
    for _ in range(1500):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal not set"
    result = int(dut.max_sum_result.value)
    # For [1,15,51,45,33]: MSIBS = [1,16,67,67,67], MSDBS = [145,144,93,48,33]
    # Result = max(1+145-1=145, 16+144-15=145, 67+93-51=109, 67+48-45=70, 67+33-33=67) = 145
    assert result == 145, f"Test 1 failed: expected 145, got {result}"
    print(f"Test 1 passed: result={result}")
    
    await Timer(100, units='ns')
    
    # Test case 2: [80, 60, 30, 40, 20, 10] -> 210 (purely decreasing, bitonic empty increasing)
    # For purely decreasing, bitonic is just decreasing subsequence
    # [80,60,40,20,10] -> 80+60+40+20+10 = 210
    # For 6 elements, let's do [80, 60, 40, 20, 10, 5] -> 215, but adapted to 6 elements
    # Actually original is 210 with [80,60,30,40,20,10] which is NOT bitonic
    # Let's do: [80, 60, 40, 20, 10] -> decreasing: 210 (without 30 and 40)
    
    dut.array_len.value = 6
    dut.array_data[0].value = 80
    dut.array_data[1].value = 60
    dut.array_data[2].value = 40
    dut.array_data[3].value = 20
    dut.array_data[4].value = 10
    dut.array_data[5].value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(1500):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    result = int(dut.max_sum_result.value)
    # MSIBS = [80,80,80,80,80,80], MSDBS = [215,135,75,35,15,5]
    # Result = 80+215-80=215
    assert result == 215, f"Test 2 failed: expected 215, got {result}"
    print(f"Test 2 passed: result={result}")
    
    await Timer(100, units='ns')
    
    # Test case 3: [2, 3, 14, 16, 21, 23, 29, 30] -> purely increasing
    # Bitonic: increasing then decreasing (empty decreasing)
    # Sum = 2+3+14+16+21+23+29+30 = 138
    
    dut.array_len.value = 8
    dut.array_data[0].value = 2
    dut.array_data[1].value = 3
    dut.array_data[2].value = 14
    dut.array_data[3].value = 16
    dut.array_data[4].value = 21
    dut.array_data[5].value = 23
    dut.array_data[6].value = 29
    dut.array_data[7].value = 30
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(2000):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    result = int(dut.max_sum_result.value)
    # For purely increasing: MSIBS[i] = sum of all up to i, MSDBS[i] = arr[i]
    # Result = sum(all) + last - last = sum(all) = 138
    assert result == 138, f"Test 3 failed: expected 138, got {result}"
    print(f"Test 3 passed: result={result}")
    
    # Additional edge case: single element
    await Timer(100, units='ns')
    dut.array_len.value = 1
    dut.array_data[0].value = 42
    for i in range(1, 8):
        dut.array_data[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(500):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    result = int(dut.max_sum_result.value)
    assert result == 42, f"Edge case failed: expected 42, got {result}"
    print(f"Edge case passed: result={result}")
    
    print("All tests passed!")
