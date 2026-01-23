import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_chocolate_cutter(dut):
    """Test the chocolate cutter module with various inputs"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    
    # Reset the dut
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    dut.k.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to calculate expected result (Python logic)
    def calculate_expected(n, m, k):
        if n + m - 2 < k:
            return 0xFFFFFFFFFFF # -1 in 40-bit
        
        max_area = 0
        max_x = min(k, n - 1)
        
        for x in range(max_x + 1):
            y = k - x
            if y <= m - 1:
                width = n // (x + 1)
                height = m // (y + 1)
                area = width * height
                if area > max_area:
                    max_area = area
        return max_area

    # Test cases: (n, m, k)
    test_cases = [
        (3, 4, 1),   # Example 1: Expected 6
        (6, 4, 2),   # Example 2: Expected 8
        (2, 3, 4),   # Example 3: Expected -1
        (10, 10, 2), # Additional: 30
        (4, 6, 4),   # Additional: 6
        (2, 2, 2),   # Boundary: Full cut, 1x1 pieces (1)
        (10, 5, 10), # Too many cuts: -1
        (5, 5, 5),   # Mid range
        (100, 100, 150), # Scaled but still fits in 10 bits (simulated if width allows, otherwise ignored)
        (8, 8, 8)    # 8x8 with 8 cuts
    ]
    
    # Filter test cases to fit 10-bit limit for simulation
    valid_tests = []
    for n, m, k in test_cases:
        if n < 1024 and m < 1024 and k < 1024:
            valid_tests.append((n, m, k))
    
    passed = 0
    total = len(valid_tests)
    
    for n, m, k in valid_tests:
        dut.n.value = n
        dut.m.value = m
        dut.k.value = k
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 2000 # Safety timeout
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
            
        if cycles >= timeout:
            raise TestFailure(f"Timeout for n={n}, m={m}, k={k}")
            
        # Read result
        actual = int(dut.result.value)
        expected = calculate_expected(n, m, k)
        
        if actual != expected:
            raise TestFailure(f"Mismatch for n={n}, m={m}, k={k}. Expected {expected}, got {actual}")
        else:
            passed += 1
            dut._log.info(f"Test passed: n={n}, m={m}, k={k} -> {actual}")
            
    print(f"{passed}/{total} tests passed")
    assert passed == total
