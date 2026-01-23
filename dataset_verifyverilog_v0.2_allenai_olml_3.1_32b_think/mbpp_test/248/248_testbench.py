import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import math

@cocotb.test()
async def test_harmonic_sum(dut):
    """Test harmonic sum calculation with fixed-point arithmetic"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert Q16.16 to float
    def q16_to_float(q16_val):
        return float(q16_val) / 65536.0
    
    # Helper function to calculate expected harmonic sum
    def harmonic_sum_expected(n):
        if n <= 1:
            return 1.0
        total = 0.0
        for k in range(1, n):
            total += 1.0 / k
        return total
    
    # Test cases adapted for n <= 16
    test_cases = [
        (1, 1.0),       # n=1, H(0) = 1
        (2, 1.0),       # n=2, H(1) = 1
        (3, 1.5),       # n=3, H(2) = 1 + 1/2 = 1.5
        (5, 2.083333333333333),  # n=5, H(4) = 1 + 1/2 + 1/3 + 1/4
        (8, 2.5928571428571425),  # n=8, H(7) = 2.592857...
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_input, expected_float in test_cases:
        # Start computation
        dut.start.value = 1
        dut.n.value = n_input
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 20  # Max cycles to wait
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            print(f"Test FAILED for n={n_input}: Timeout waiting for done")
            continue
        
        # Read result
        result_q16 = int(dut.result.value)
        result_float = q16_to_float(result_q16)
        
        # Calculate expected in Q16.16
        expected_q16 = int(expected_float * 65536)
        
        # Check with tolerance (account for fixed-point rounding)
        tolerance = 0.01  # 1% tolerance for fixed-point errors
        
        print(f"n={n_input}: Expected {expected_float:.6f} (0x{expected_q16:08X}), Got {result_float:.6f} (0x{result_q16:08X})")
        
        if abs(result_float - expected_float) < tolerance:
            passed += 1
            print(f"  PASS")
        else:
            print(f"  FAIL: Error {abs(result_float - expected_float):.6f} exceeds tolerance {tolerance}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
