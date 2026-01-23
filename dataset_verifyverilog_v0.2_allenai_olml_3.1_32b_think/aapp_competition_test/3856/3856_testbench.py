import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_photo_optimizer(dut):
    """Test photo optimizer with various inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.friend_w.value = 0
    dut.friend_h.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (w0, h0, w1, h1, w2, h2, w3, h3, expected_area)
    # Scaled down from original but maintaining relative complexity
    test_cases = [
        # Example 1: 3 friends (use 4 with dummy) - simplified from original
        (10, 1, 20, 2, 30, 3, 0, 0, 180),  # Original had 3, adapted
        # Example 2: 3 friends
        (3, 1, 2, 2, 4, 3, 0, 0, 21),
        # Example 3: 1 friend
        (5, 10, 0, 0, 0, 0, 0, 0, 50),
        # Example 4: Simple 2x2
        (1, 1, 0, 0, 0, 0, 0, 0, 1),
        # Example 5: Large square
        (1000, 1000, 0, 0, 0, 0, 0, 0, 1000000),
        # Example 6: Tall and skinny
        (1, 1000, 0, 0, 0, 0, 0, 0, 1000),
        # Example 7: Two friends, one very tall, one very wide
        (1, 1000, 1000, 1, 0, 0, 0, 0, 2000),
        # Example 8: Two friends, both large
        (1, 1, 1000, 1000, 0, 0, 0, 0, 1001000),
        # Example 9: Single wide friend
        (1000, 1, 0, 0, 0, 0, 0, 0, 1000),
        # Example 10: Two identical small friends
        (1, 1, 1, 1, 0, 0, 0, 0, 2),
        # Example 11: Four friends with mixed orientations
        (100, 200, 300, 400, 500, 600, 700, 800, 600000),
        # Example 12: Vertical orientation preference test
        (50, 100, 200, 300, 10, 5, 80, 120, 22000),
        # Example 13: Edge case - all same dimensions
        (10, 10, 10, 10, 10, 10, 10, 10, 400),
        # Example 14: Mixed with lie-down constraint active
        (500, 300, 400, 200, 600, 100, 300, 500, 480000),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (w0, h0, w1, h1, w2, h2, w3, h3, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}/{total}: Input dims = ({w0},{h0}), ({w1},{h1}), ({w2},{h2}), ({w3},{h3}), Expected = {expected}")
        
        # Load inputs
        dut.friend_w.value = (w0, w1, w2, w3)
        dut.friend_h.value = (h0, h1, h2, h3)
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion with timeout
        timeout = 0
        while not dut.done.value and timeout < 10000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 10000:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Read result
        result = int(dut.min_area.value)
        
        if result == expected:
            dut._log.info(f"  PASS: Got {result}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: Got {result}, Expected {expected}")
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")

@cocotb.test()
async def test_photo_optimizer_corner_cases(dut):
    """Test corner cases"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: 1x1 repeated 4 times
    dut._log.info("Testing all 1x1 friends...")
    dut.friend_w.value = (1, 1, 1, 1)
    dut.friend_h.value = (1, 1, 1, 1)
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result = int(dut.min_area.value)
    assert result == 4, f"Expected 4, got {result}"
    dut._log.info(f"PASS: 1x1 test result = {result}")
    
    # Test case: Maximum single friend
    dut._log.info("Testing maximum single friend (1000x1000)...")
    dut.friend_w.value = (1000, 0, 0, 0)
    dut.friend_h.value = (1000, 0, 0, 0)
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result = int(dut.min_area.value)
    assert result == 1000000, f"Expected 1000000, got {result}"
    dut._log.info(f"PASS: Max friend test result = {result}")
    
    dut._log.info("
=== All corner case tests passed ===")
