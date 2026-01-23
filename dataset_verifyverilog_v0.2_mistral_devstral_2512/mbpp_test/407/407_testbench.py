import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_rearrange_bigger(dut):
    """Test rearrange_bigger module with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number_in.value = 0
    await Timer(30, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (12, 21, True),     # Test 1: 12 -> 21
        (10, 0xFFF, False), # Test 2: 10 -> no bigger (0xFFF)
        (102, 120, True),   # Test 3: 102 -> 120
        (21, 0xFFF, False), # Edge case: 21 -> no bigger
        (123, 132, True),   # Additional: 123 -> 132
        (111, 0xFFF, False), # All same digits
        (987, 0xFFF, False), # Descending order
        (120, 201, True),   # Additional: 120 -> 201
        (201, 210, True),   # Additional: 201 -> 210
        (301, 310, True)    # Additional: 301 -> 310
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (num_in, expected, should_be_valid) in enumerate(test_cases):
        dut.number_in.value = num_in
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 18 cycles)
        timeout = 20
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check results
        result = int(dut.result.value)
        valid = int(dut.valid.value)
        
        if should_be_valid:
            if result == expected and valid == 1:
                passed += 1
                print(f"Test {i+1}: {num_in} -> {result} (expected {expected}) ✓")
            else:
                print(f"Test {i+1}: {num_in} -> {result} (expected {expected}) ✗")
        else:
            if result == expected and valid == 0:
                passed += 1
                print(f"Test {i+1}: {num_in} -> no result (expected 0xFFF) ✓")
            else:
                print(f"Test {i+1}: {num_in} -> {result} (expected 0xFFF) ✗")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Expected {total} tests to pass, but only {passed} passed"
