import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def calculate_expected_python(weights):
    """Calculate expected weight using Python for verification"""
    total_sum = sum(weights)
    return total_sum / 4.0

def calculate_distinct_python(weights):
    """Calculate number of distinct 4-pack weights"""
    sums = set()
    for a in weights:
        for b in weights:
            for c in weights:
                for d in weights:
                    sums.add(a + b + c + d)
    return len(sums)

@cocotb.test()
async def test_4pack_basic(dut):
    """Test basic functionality with small weights"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.w0.value = 0
    dut.w1.value = 0
    dut.w2.value = 0
    dut.w3.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: weights = [1, 2, 4, 7]
    weights = [1, 2, 4, 7]
    dut.w0.value = weights[0]
    dut.w1.value = weights[1]
    dut.w2.value = weights[2]
    dut.w3.value = weights[3]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while dut.done.value == 0 and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Timeout waiting for done signal")
    
    # Expected values: max=28, min=4, distinct=21, expected=14.0
    max_exp = 28
    min_exp = 4
    distinct_exp = 21
    expected_exp = 14.0
    
    # Read outputs
    max_val = int(dut.max_weight.value)
    min_val = int(dut.min_weight.value)
    distinct_val = int(dut.distinct_weights_count.value)
    
    # Expected is in Q16.16, convert back to float
    expected_val_q16 = int(dut.expected_weight.value)
    expected_val_float = expected_val_q16 / 65536.0
    
    print(f"Test 1 - Weights {weights}")
    print(f"  Max: {max_val} (expected {max_exp})")
    print(f"  Min: {min_val} (expected {min_exp})")
    print(f"  Distinct: {distinct_val} (expected {distinct_exp})")
    print(f"  Expected: {expected_val_float:.4f} (expected {expected_exp:.4f})")
    
    if max_val != max_exp:
        raise TestFailure(f"Max weight mismatch: got {max_val}, expected {max_exp}")
    if min_val != min_exp:
        raise TestFailure(f"Min weight mismatch: got {min_val}, expected {min_exp}")
    if distinct_val != distinct_exp:
        raise TestFailure(f"Distinct count mismatch: got {distinct_val}, expected {distinct_exp}")
    if abs(expected_val_float - expected_exp) > 0.0001:
        raise TestFailure(f"Expected weight mismatch: got {expected_val_float}, expected {expected_exp}")

@cocotb.test()
async def test_4pack_second_case(dut):
    """Test with second example: weights = [2, 5, 4] but need 4 distinct weights"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.w0.value = 0
    dut.w1.value = 0
    dut.w2.value = 0
    dut.w3.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: Use weights that give same output as example
    # Example output 20 8 12 14.66666667
    # Let's use weights = [2, 4, 5, 6] to match the pattern
    # Actually, let's calculate for [2, 4, 5, 6]: max=24, min=8, expected=(2+4+5+6)/4=4.25
    # For [2, 3, 4, 6]: max=24, min=8, expected=3.75
    # The example [2,5,4] with N=3 means only 3 weights, but we need 4.
    # Let's use weights = [2, 3, 4, 5] to test
    weights = [2, 3, 4, 5]
    dut.w0.value = weights[0]
    dut.w1.value = weights[1]
    dut.w2.value = weights[2]
    dut.w3.value = weights[3]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while dut.done.value == 0 and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Timeout waiting for done signal")
    
    # Calculate expected values
    max_exp = max(weights) * 4  # 5*4=20
    min_exp = min(weights) * 4  # 2*4=8
    distinct_exp = calculate_distinct_python(weights)
    expected_exp = calculate_expected_python(weights)
    
    # Read outputs
    max_val = int(dut.max_weight.value)
    min_val = int(dut.min_weight.value)
    distinct_val = int(dut.distinct_weights_count.value)
    expected_val_q16 = int(dut.expected_weight.value)
    expected_val_float = expected_val_q16 / 65536.0
    
    print(f"
Test 2 - Weights {weights}")
    print(f"  Max: {max_val} (expected {max_exp})")
    print(f"  Min: {min_val} (expected {min_exp})")
    print(f"  Distinct: {distinct_val} (expected {distinct_exp})")
    print(f"  Expected: {expected_val_float:.4f} (expected {expected_exp:.4f})")
    
    if max_val != max_exp:
        raise TestFailure(f"Max weight mismatch: got {max_val}, expected {max_exp}")
    if min_val != min_exp:
        raise TestFailure(f"Min weight mismatch: got {min_val}, expected {min_exp}")
    if distinct_val != distinct_exp:
        raise TestFailure(f"Distinct count mismatch: got {distinct_val}, expected {distinct_exp}")
    if abs(expected_val_float - expected_exp) > 0.0001:
        raise TestFailure(f"Expected weight mismatch: got {expected_val_float}, expected {expected_exp}")

@cocotb.test()
async def test_4pack_edge_cases(dut):
    """Test edge cases: all same weights and max spread"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: All weights same (except we need 4 distinct, so use close values)
    weights = [10, 11, 12, 13]
    dut.w0.value = weights[0]
    dut.w1.value = weights[1]
    dut.w2.value = weights[2]
    dut.w3.value = weights[3]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Timeout waiting for done signal")
    
    # Expected values
    max_exp = 13 * 4  # 52
    min_exp = 10 * 4  # 40
    distinct_exp = calculate_distinct_python(weights)
    expected_exp = calculate_expected_python(weights)
    
    max_val = int(dut.max_weight.value)
    min_val = int(dut.min_weight.value)
    distinct_val = int(dut.distinct_weights_count.value)
    expected_val_q16 = int(dut.expected_weight.value)
    expected_val_float = expected_val_q16 / 65536.0
    
    print(f"
Test 3 - Weights {weights}")
    print(f"  Max: {max_val} (expected {max_exp})")
    print(f"  Min: {min_val} (expected {min_exp})")
    print(f"  Distinct: {distinct_val} (expected {distinct_exp})")
    print(f"  Expected: {expected_val_float:.4f} (expected {expected_exp:.4f})")
    
    if max_val != max_exp:
        raise TestFailure(f"Max weight mismatch: got {max_val}, expected {max_exp}")
    if min_val != min_exp:
        raise TestFailure(f"Min weight mismatch: got {min_val}, expected {min_exp}")
    if distinct_val != distinct_exp:
        raise TestFailure(f"Distinct count mismatch: got {distinct_val}, expected {distinct_exp}")
    if abs(expected_val_float - expected_exp) > 0.0001:
        raise TestFailure(f"Expected weight mismatch: got {expected_val_float}, expected {expected_exp}")

@cocotb.test()
async def test_4pack_large_weights(dut):
    """Test with larger weights close to 255"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 4: Larger weights
    weights = [100, 150, 200, 250]
    dut.w0.value = weights[0]
    dut.w1.value = weights[1]
    dut.w2.value = weights[2]
    dut.w3.value = weights[3]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Timeout waiting for done signal")
    
    # Expected values
    max_exp = 250 * 4  # 1000
    min_exp = 100 * 4  # 400
    distinct_exp = calculate_distinct_python(weights)
    expected_exp = calculate_expected_python(weights)
    
    max_val = int(dut.max_weight.value)
    min_val = int(dut.min_weight.value)
    distinct_val = int(dut.distinct_weights_count.value)
    expected_val_q16 = int(dut.expected_weight.value)
    expected_val_float = expected_val_q16 / 65536.0
    
    print(f"
Test 4 - Weights {weights}")
    print(f"  Max: {max_val} (expected {max_exp})")
    print(f"  Min: {min_val} (expected {min_exp})")
    print(f"  Distinct: {distinct_val} (expected {distinct_exp})")
    print(f"  Expected: {expected_val_float:.4f} (expected {expected_exp:.4f})")
    
    if max_val != max_exp:
        raise TestFailure(f"Max weight mismatch: got {max_val}, expected {max_exp}")
    if min_val != min_exp:
        raise TestFailure(f"Min weight mismatch: got {min_val}, expected {min_exp}")
    if distinct_val != distinct_exp:
        raise TestFailure(f"Distinct count mismatch: got {distinct_val}, expected {distinct_exp}")
    if abs(expected_val_float - expected_exp) > 0.0001:
        raise TestFailure(f"Expected weight mismatch: got {expected_val_float}, expected {expected_exp}")

@cocotb.test()
async def test_4pack_minimal_weights(dut):
    """Test with minimal weights"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 5: Minimal weights
    weights = [1, 2, 3, 4]
    dut.w0.value = weights[0]
    dut.w1.value = weights[1]
    dut.w2.value = weights[2]
    dut.w3.value = weights[3]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Timeout waiting for done signal")
    
    # Expected values
    max_exp = 4 * 4  # 16
    min_exp = 1 * 4  # 4
    distinct_exp = calculate_distinct_python(weights)
    expected_exp = calculate_expected_python(weights)
    
    max_val = int(dut.max_weight.value)
    min_val = int(dut.min_weight.value)
    distinct_val = int(dut.distinct_weights_count.value)
    expected_val_q16 = int(dut.expected_weight.value)
    expected_val_float = expected_val_q16 / 65536.0
    
    print(f"
Test 5 - Weights {weights}")
    print(f"  Max: {max_val} (expected {max_exp})")
    print(f"  Min: {min_val} (expected {min_exp})")
    print(f"  Distinct: {distinct_val} (expected {distinct_exp})")
    print(f"  Expected: {expected_val_float:.4f} (expected {expected_exp:.4f})")
    
    # Count tests
    tests_passed = 0
    tests_total = 5
    
    if max_val == max_exp:
        tests_passed += 1
    if min_val == min_exp:
        tests_passed += 1
    if distinct_val == distinct_exp:
        tests_passed += 1
    if abs(expected_val_float - expected_exp) <= 0.0001:
        tests_passed += 1
    
    print(f"
=== Summary: {tests_passed}/{tests_total * 4} assertions passed ===")
    
    if max_val != max_exp:
        raise TestFailure(f"Max weight mismatch: got {max_val}, expected {max_exp}")
    if min_val != min_exp:
        raise TestFailure(f"Min weight mismatch: got {min_val}, expected {min_exp}")
    if distinct_val != distinct_exp:
        raise TestFailure(f"Distinct count mismatch: got {distinct_val}, expected {distinct_exp}")
    if abs(expected_val_float - expected_exp) > 0.0001:
        raise TestFailure(f"Expected weight mismatch: got {expected_val_float}, expected {expected_exp}")