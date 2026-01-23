import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def calc_deviation(p, shift, n=8):
    """Calculate deviation for a given shift"""
    dev = 0
    for i in range(n):
        expected = (i + shift) % n + 1
        val = p[i]
        dev += abs(val - expected)
    return dev

def pack_permutation(p):
    """Pack permutation into 64-bit integer"""
    result = 0
    for i in range(8):
        result |= (p[i] << (i * 8))
    return result

@cocotb.test()
async def test_min_perm_deviation(dut):
    """Test the min_perm_deviation module with various permutations"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 8
    dut.p_in.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled to n=8)
    test_cases = [
        # (permutation, expected_min_dev, expected_shift)
        ([1, 2, 3, 4, 5, 6, 7, 8], 0, 0),   # Identity
        ([2, 3, 4, 5, 6, 7, 8, 1], 0, 1),   # Shift 1
        ([8, 1, 2, 3, 4, 5, 6, 7], 0, 7),   # Shift 7
        ([8, 7, 6, 5, 4, 3, 2, 1], 28, 0),  # Reverse
        ([2, 1, 3, 4, 5, 6, 7, 8], 2, 0),   # Swap first two
        ([1, 3, 2, 4, 5, 6, 7, 8], 2, 0),   # Swap 2nd and 3rd
    ]
    
    passed = 0
    total = len(test_cases)
    
    for p, exp_dev, exp_shift in test_cases:
        dut._log.info(f"Testing permutation {p}")
        
        # Load input
        dut.p_in.value = pack_permutation(p)
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 30 cycles)
        timeout = 30
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            dut._log.error("Timeout waiting for done")
            continue
        
        # Read results
        min_dev = int(dut.min_deviation.value)
        best_shift = int(dut.best_shift.value)
        
        # Verify
        if min_dev == exp_dev and best_shift == exp_shift:
            passed += 1
            dut._log.info(f"PASS: dev={min_dev}, shift={best_shift}")
        else:
            # Try to find if any shift matches the found minimum
            found_min = min(calc_deviation(p, i) for i in range(8))
            if min_dev == found_min:
                passed += 1
                dut._log.info(f"PASS: dev={min_dev}, shift={best_shift} (alternative optimal)")
            else:
                dut._log.error(f"FAIL: Expected dev={exp_dev}, shift={exp_shift}, Got dev={min_dev}, shift={best_shift}")
                dut._log.error(f"  True minimum is {found_min}")
    
    # Edge case: verify module handles all shifts 0..7
    dut._log.info("Testing edge case: all shifts of [1,2,3,4,5,6,7,8]")
    p = [1, 2, 3, 4, 5, 6, 7, 8]
    for shift in range(8):
        dut.p_in.value = pack_permutation(p)
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for _ in range(30):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        min_dev = int(dut.min_deviation.value)
        best_shift = int(dut.best_shift.value)
        if min_dev == 0 and best_shift == shift:
            passed += 1
        # Rotate permutation
        p = [p[-1]] + p[:-1]
    
    total += 8
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
