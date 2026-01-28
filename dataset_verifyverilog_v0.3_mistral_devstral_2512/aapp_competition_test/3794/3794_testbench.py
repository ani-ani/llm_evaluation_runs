import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 8
MAX_CYCLES = 1000
CLK_PERIOD_NS = 10

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def gcd(a, b):
    if b == 0:
        return a
    return gcd(b, a % b)

def gcd_list(arr):
    if not arr:
        return 0
    result = arr[0]
    for x in arr[1:]:
        result = gcd(result, x)
    return result

def solve_python(arr):
    """Brute force all splits for n=8"""
    n = len(arr)
    for mask in range(1, (1 << n) - 1):
        group1 = [arr[i] for i in range(n) if mask & (1 << i)]
        group2 = [arr[i] for i in range(n) if not mask & (1 << i)]
        if gcd_list(group1) == 1 and gcd_list(group2) == 1:
            return True, mask
    return False, 0

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_gcd_split(dut):
    """Test the GCD split module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled for n=8)
    test_cases = [
        # (arr_0 to arr_7, description)
        ([2, 3, 6, 7, 1, 1, 1, 1], "Small case - should find split"),
        ([6, 15, 35, 77, 22, 1, 1, 1], "Medium case - should find split"),
        ([6, 10, 15, 1000, 75, 1, 1, 1], "Hard case - no split"),
        ([1, 2, 3, 4, 5, 6, 7, 8], "All coprime - should work"),
        ([2, 4, 6, 8, 10, 12, 14, 16], "All even - no split"),
        ([1, 1, 1, 1, 1, 1, 1, 1], "All ones - should work"),
        ([2, 3, 5, 7, 11, 13, 17, 19], "Primes - should work"),
        ([4, 6, 8, 9, 10, 12, 14, 15], "Mixed - test case"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, description) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: {description}")
        dut._log.info(f"Input array: {arr_vals}")
        
        # Calculate expected result
        exp_possible, exp_mask = solve_python(arr_vals)
        dut._log.info(f"Expected: {'YES' if exp_possible else 'NO'}")
        if exp_possible:
            exp_assignments = [(exp_mask >> j) & 1 for j in range(8)]
            dut._log.info(f"Expected mask: {exp_assignments}")
        
        # Write inputs individually
        for j in range(8):
            val = arr_vals[j] if j < len(arr_vals) else 1
            getattr(dut, f'arr_{j}').value = clamp_to_width(val, DATA_WIDTH)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Read results
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result signal undefined")
        
        actual_possible = int(dut.result.value) == 1
        actual_mask = int(dut.assignment.value)
        
        dut._log.info(f"Actual: {'YES' if actual_possible else 'NO'}")
        if actual_possible:
            actual_assignments = [(actual_mask >> j) & 1 for j in range(8)]
            dut._log.info(f"Actual mask: {actual_assignments}")
        
        # Verify
        if actual_possible != exp_possible:
            dut._log.error(f"FAIL: Expected {'YES' if exp_possible else 'NO'}, got {'YES' if actual_possible else 'NO'}")
            failed += 1
        elif actual_possible and exp_possible:
            # Verify the split actually works
            group1 = [arr_vals[j] for j in range(8) if (actual_mask >> j) & 1]
            group2 = [arr_vals[j] for j in range(8) if not ((actual_mask >> j) & 1)]
            
            if not group1 or not group2:
                dut._log.error("FAIL: Empty group in split")
                failed += 1
            elif gcd_list(group1) != 1 or gcd_list(group2) != 1:
                dut._log.error(f"FAIL: GCD check failed - group1 GCD={gcd_list(group1)}, group2 GCD={gcd_list(group2)}")
                failed += 1
            else:
                dut._log.info("PASS")
                passed += 1
        else:
            dut._log.info("PASS")
            passed += 1
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info("\n" + "="*50)
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")