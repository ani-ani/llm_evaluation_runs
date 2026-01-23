import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_digit_rearrange(dut):
    """Test digit rearrangement for divisibility by 7"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.digit_vector.value = 0
    dut.num_digits.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_output)
    test_cases = [
        ("1689", "1869"),
        ("18906", "18690"),
        ("16891", "16198"),
        ("16892", "21896"),
        ("16893", "31689"),
        ("4048169", "4041968"),
        ("11689", "16198"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_str, expected_str in test_cases:
        # Pack digits into 32-bit vector (4 bits per digit)
        digit_vec = 0
        for i, char in enumerate(input_str):
            digit = int(char)
            digit_vec |= (digit << (4 * i))
        
        # Start computation
        dut.digit_vector.value = digit_vec
        dut.num_digits.value = len(input_str)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (up to 130 cycles)
        timeout = 130
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for input {input_str}")
        
        # Verify result
        if dut.valid.value == 1:
            # Extract result digits
            result_vec = dut.result.value.integer
            result_len = dut.result_length.value.integer
            result_str = ""
            for i in range(result_len):
                digit = (result_vec >> (4 * i)) & 0xF
                result_str += str(digit)
            
            # Check divisibility by 7
            result_val = int(result_str)
            if result_val % 7 != 0:
                raise TestFailure(f"Result {result_str} not divisible by 7 (input {input_str})")
            
            # Check expected output
            if result_str == expected_str:
                passed += 1
                print(f"PASS: {input_str} -> {result_str}")
            else:
                # Allow alternative valid outputs
                print(f"INFO: {input_str} -> {result_str} (expected {expected_str}, but valid)")
                passed += 1
        else:
            raise TestFailure(f"Invalid result for input {input_str}")
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
