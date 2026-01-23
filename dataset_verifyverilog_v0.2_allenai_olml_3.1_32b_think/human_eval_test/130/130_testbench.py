import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_tribonacci_basic(dut):
    """Test basic Tribonacci sequence calculations"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_result_Q16_16)
    # tri(0)=1, tri(1)=3, tri(2)=2, tri(3)=8, tri(4)=3, tri(5)=15, tri(6)=4, tri(7)=24, tri(8)=5, tri(9)=35, tri(10)=6
    test_cases = [
        (0, 1 * 65536),
        (1, 3 * 65536),
        (2, 2 * 65536),
        (3, 8 * 65536),
        (4, 3 * 65536),
        (5, 15 * 65536),
        (6, 4 * 65536),
        (7, 24 * 65536),
        (8, 5 * 65536),
        (9, 35 * 65536),
        (10, 6 * 65536),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for busy to go high then low
        timeout = 0
        while dut.busy.value == 0 and timeout < 50:
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Wait for valid
        timeout = 0
        while dut.valid.value == 0 and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            dut._log.error(f"Timeout waiting for valid for n={n}")
            continue
        
        # Read result
        actual = int(dut.result.value)
        
        # Allow small tolerance for fixed-point rounding
        diff = abs(actual - expected)
        if diff <= 2:  # 2/65536 ≈ 0.00003 tolerance
            passed += 1
            dut._log.info(f"n={n}: PASS (got {actual}, expected {expected})")
        else:
            dut._log.error(f"n={n}: FAIL (got {actual}, expected {expected}, diff={diff})")
        
        # Wait before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
=== Results: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
async def test_tribonacci_sequence(dut):
    """Test that sequence builds correctly"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Expected sequence values
    expected_seq = [1, 3, 2, 8, 3, 15, 4, 24, 5, 35, 6]
    
    results = []
    
    for n in range(11):
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for valid
        while dut.valid.value == 0:
            await RisingEdge(dut.clk)
        
        results.append(int(dut.result.value) / 65536.0)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Computed sequence: {results}")
    dut._log.info(f"Expected sequence: {expected_seq}")
    
    # Check all values
    all_match = True
    for i, (actual, expected) in enumerate(zip(results, expected_seq)):
        if abs(actual - expected) > 0.001:
            dut._log.error(f"Mismatch at index {i}: {actual} vs {expected}")
            all_match = False
    
    assert all_match, "Sequence does not match expected values"
