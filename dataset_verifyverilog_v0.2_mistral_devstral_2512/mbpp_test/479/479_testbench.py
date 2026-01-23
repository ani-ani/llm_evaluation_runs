import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_first_digit(dut):
    """Test first_digit module with various test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (123, 1),   # Test 1: 123 -> 1
        (456, 4),   # Test 2: 456 -> 4
        (12, 1),    # Test 3: 12 -> 1
        (7, 7),     # Edge case: single digit
        (999999999, 9),  # Large 9-digit number
        (100, 1),   # Powers of 10
        (987654321, 9), # 9-digit descending
    ]
    
    passed = 0
    total = len(test_cases)
    
    for num_val, expected in test_cases:
        # Start computation
        dut.num.value = num_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        timeout = 20  # max cycles to wait
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for input {num_val}")
        
        # Check result
        result = int(dut.first_digit.value)
        if result == expected:
            print(f"PASS: first_digit({num_val}) = {result} (expected {expected})")
            passed += 1
        else:
            print(f"FAIL: first_digit({num_val}) = {result} (expected {expected})")
            raise TestFailure(f"Expected {expected}, got {result}")
        
        # Wait before next test
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed == total:
        print("All tests passed!")
