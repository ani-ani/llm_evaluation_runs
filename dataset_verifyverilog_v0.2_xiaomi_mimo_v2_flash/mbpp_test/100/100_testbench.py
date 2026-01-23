import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_next_smallest_palindrome(dut):
    """Test next_smallest_palindrome module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (99, 101),
        (1221, 1331),
        (120, 121),
        (9, 11),
        (8, 9),
        (10, 11),
        (123, 131),
        (1000, 1001)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for input_val, expected in test_cases:
        if input_val > 65535:
            print(f"Skipping test {input_val} -> {expected} (out of range)")
            total -= 1
            continue
            
        dut.num_in.value = input_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 100 cycles for safety)
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            raise TestFailure(f"Timeout for input {input_val}")
        
        result = int(dut.result.value)
        
        # Verify palindrome property
        result_str = str(result)
        is_palindrome = result_str == result_str[::-1]
        
        # Verify it's greater than input
        is_greater = result > input_val
        
        if result != expected:
            print(f"FAIL: Input={input_val}, Expected={expected}, Got={result}")
        elif not is_palindrome:
            print(f"FAIL: Result {result} is not a palindrome")
        elif not is_greater:
            print(f"FAIL: Result {result} not greater than input {input_val}")
        else:
            print(f"PASS: Input={input_val} -> Result={result}")
            passed += 1
        
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"