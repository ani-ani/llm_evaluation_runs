import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Reference implementation for verification
def reference_modp(n, p):
    """Reference Python implementation of 2^n mod p"""
    if p == 1:
        return 0
    return pow(2, n, p)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_modp_basic(dut):
    """Test basic functionality of modp module"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.p.value = 1
    
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (n, p, expected_result)
    # Calculated using reference_modp function
    test_cases = [
        (3, 5, 3),       # 2^3 mod 5 = 8 mod 5 = 3
        (1101, 101, 2),  # 2^1101 mod 101 (n scaled to 8-bit: 1101 & 0xFF = 85, 2^85 mod 101 = 2)
        (0, 101, 1),     # 2^0 mod 101 = 1 mod 101 = 1
        (3, 11, 8),      # 2^3 mod 11 = 8 mod 11 = 8
        (100, 101, 1),   # 2^100 mod 101 = 1
        (30, 5, 4),      # 2^30 mod 5
        (31, 5, 3),      # 2^31 mod 5
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for i, (n, p, expected) in enumerate(test_cases):
        # Calculate expected using python (handles the modulo correctly)
        # Note: n=1101 is larger than 8-bit, need to mask to 8 bits as per hardware spec
        actual_n = n & 0xFF
        expected_result = reference_modp(actual_n, p)
        
        dut._log.info(f"Test {i+1}: n={actual_n} (orig {n}), p={p}, expected={expected_result}")
        
        # Apply inputs
        dut.n.value = actual_n
        dut.p.value = p
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 20 cycles to be safe)
        done_seen = False
        for cycle in range(20):
            await RisingEdge(dut.clk)
            if not is_value_defined(dut.done.value):
                continue
            if dut.done.value == 1:
                done_seen = True
                break
        
        if not done_seen:
            raise TestFailure(f"Test {i+1}: Done signal not asserted within 20 cycles")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")
            
        actual_result = int(dut.result.value)
        
        if actual_result != expected_result:
            raise TestFailure(f"Test {i+1}: n={actual_n}, p={p} -> Expected {expected_result}, got {actual_result}")
        
        dut._log.info(f"Test {i+1} passed: result={actual_result}")
        passed += 1
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nSUMMARY: {passed}/{total} tests passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_modp_edge_cases(dut):
    """Test edge cases for modp module"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    edge_cases = [
        (0, 1, 0),     # 2^0 mod 1 = 0 (special case mod 1)
        (1, 255, 2),   # 2^1 mod 255 = 2
        (255, 253, 8), # 2^255 mod 253 (n=255 is max)
    ]
    
    for i, (n, p, expected) in enumerate(edge_cases):
        # Calculate actual expected for scaled inputs
        actual_expected = reference_modp(n, p)
        
        dut._log.info(f"Edge case {i+1}: n={n}, p={p}, expected={actual_expected}")
        
        dut.n.value = n
        dut.p.value = p
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for _ in range(20):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Edge case {i+1}: Result undefined")
            
        actual = int(dut.result.value)
        
        if actual != actual_expected:
            raise TestFailure(f"Edge case {i+1}: n={n}, p={p} -> Expected {actual_expected}, got {actual}")
        
        dut._log.info(f"Edge case {i+1} passed")
        await RisingEdge(dut.clk)
    
    dut._log.info("Edge cases passed")
