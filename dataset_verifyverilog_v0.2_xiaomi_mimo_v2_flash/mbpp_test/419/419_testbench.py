import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def float_to_fixed(f):
    """Convert float to Q16.16 fixed-point representation"""
    return int(f * 65536) & 0xFFFFFFFF

def fixed_to_float(fixed):
    """Convert Q16.16 fixed-point to float"""
    # Sign extension for negative numbers
    if fixed & 0x80000000:
        fixed = fixed - 0x100000000
    return fixed / 65536.0

def round_and_sum_reference(list1):
    """Reference Python implementation"""
    length = len(list1)
    rounded = [round(x) for x in list1]
    total = sum(rounded) * length
    return total

@cocotb.test()
async def test_round_and_sum(dut):
    """Test round_and_sum module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.list_length.value = 0
    for i in range(8):
        dut.list_data[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([22.4, 4.0, -16.22, -9.10, 11.00, -12.22, 14.20, -5.20, 17.50], 243),
        ([5, 2, 9, 24.3, 29], 345),
        ([25.0, 56.7, 89.2], 513)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_num, (float_list, expected) in enumerate(test_cases, 1):
        # Prepare inputs
        n = len(float_list)
        dut.list_length.value = n
        
        # Fill list_data with fixed-point values
        for i in range(8):
            if i < n:
                fixed_val = float_to_fixed(float_list[i])
                dut.list_data[i].value = fixed_val
            else:
                dut.list_data[i].value = 0
        
        print(f"
Test {test_num}: Input = {float_list}")
        print(f"  Expected integer result: {expected}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"  FAILED: Timeout waiting for done signal")
            continue
        
        # Read result (Q16.16 format)
        result_fixed = int(dut.result.value)
        result_float = fixed_to_float(result_fixed)
        result_int = int(result_float)  # Integer part only
        
        print(f"  Result (Q16.16): 0x{result_fixed:08X}")
        print(f"  Result (float): {result_float}")
        print(f"  Result (integer): {result_int}")
        print(f"  Cycles taken: {cycles}")
        
        if result_int == expected:
            print(f"  PASSED")
            passed += 1
        else:
            print(f"  FAILED: Expected {expected}, got {result_int}")
        
        await RisingEdge(dut.clk)
    
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed}/{total} tests passed")
    print(f"{'='*50}")
    
    assert passed == total, f"Only {passed} out of {total} tests passed"
