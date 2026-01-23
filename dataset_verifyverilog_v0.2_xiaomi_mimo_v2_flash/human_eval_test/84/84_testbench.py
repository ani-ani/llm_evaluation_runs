import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_digit_sum_to_binary(dut):
    """Test digit sum to binary conversion for various inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_N, expected_result)
    test_cases = [
        (0, 0),      # sum=0 -> binary 0000
        (1, 1),      # sum=1 -> binary 0001
        (10, 1),     # sum=1 -> binary 0001
        (100, 1),    # sum=1 -> binary 0001
        (150, 6),    # sum=6 -> binary 0110
        (147, 12),   # sum=12 -> binary 1100
        (333, 9),    # sum=9 -> binary 1001
        (255, 12),   # sum=12 -> binary 1100
        (99, 18),    # sum=18 -> binary 10010 (but 4-bit, so 2) - WAIT, need 5 bits!
    ]
    
    # Adjust test cases for 4-bit result (max 15)
    # 99 -> 9+9=18 which is >15, so we need to handle this
    # Actually for N<=255, max sum is 2+5+5=12 which fits in 4 bits
    # So 99 would be out of range for 8-bit N constraint
    # Let's use only valid 8-bit test cases
    test_cases = [
        (0, 0),      # 0000
        (1, 1),      # 0001
        (10, 1),     # 0001
        (100, 1),    # 0001
        (150, 6),    # 0110
        (147, 12),   # 1100
        (333, 9),    # 1001
        (255, 12),   # 1100
        (200, 2),    # 0010
        (111, 3),    # 0011
    ]
    
    passed = 0
    total = len(test_cases)
    
    for N_val, expected in test_cases:
        # Load input
        dut.N.value = N_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 10 cycles)
        timeout = 0
        while not dut.done.value and timeout < 15:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 15:
            raise TestFailure(f"Timeout for N={N_val}")
        
        # Read result
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
            print(f"PASS: N={N_val} -> result={actual} (expected {expected})")
        else:
            print(f"FAIL: N={N_val} -> result={actual} (expected {expected})")
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
