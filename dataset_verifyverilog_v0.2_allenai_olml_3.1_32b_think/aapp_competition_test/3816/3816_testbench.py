import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def calculate_expected(a, b, c, l):
    """Calculate expected result using Python logic (scaled to 8-bit inputs)"""
    # Total ways: (l+3)*(l+2)*(l+1)/6
    # Since we are in Q16.16, multiply by 2^16
    total = ((l + 3) * (l + 2) * (l + 1) // 6) * 65536
    
    invalid = 0
    for stick in [a, b, c]:
        for x in range(l + 1):
            s = 2 * stick - a - b - c
            val = s + x
            if val < 0:
                continue
            m = min(val, l - x)
            invalid += (m + 1) * (m + 2) // 2
    
    # Convert invalid to Q16.16
    invalid *= 65536
    return total - invalid

@cocotb.test()
def test_triangle_ways(dut):
    """Test triangle ways calculation"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    dut.c.value = 0
    dut.l.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (1, 1, 1, 2),   # Expected: 4
        (1, 2, 3, 1),   # Expected: 2
        (10, 2, 1, 7),  # Expected: 0
        (1, 2, 1, 5),   # Expected: 20
        (5, 5, 5, 10),  # Expected: 41841675001 (scaled down, will be different)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for a, b, c, l in test_cases:
        # Scale inputs to fit 8-bit (we'll use values as-is since they fit 0-255)
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        dut.l.value = l
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Timeout for test case {a},{b},{c},{l}")
        
        # Read result
        result = dut.result.value
        expected = calculate_expected(a, b, c, l)
        
        # Allow small rounding errors
        diff = abs(int(result) - expected)
        if diff < 1000:  # 1/65536 tolerance
            passed += 1
        else:
            dut._log.error(f"Test ({a},{b},{c},{l}) Failed: Got {int(result)}, Expected {expected}, Diff {diff}")
    
    print(f"
SUMMARY: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
