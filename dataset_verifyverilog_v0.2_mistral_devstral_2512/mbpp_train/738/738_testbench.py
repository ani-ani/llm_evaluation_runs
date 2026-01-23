import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import numpy as np

# Helper function to convert float to Q16.16 fixed-point
def float_to_q16_16(value):
    return int(value * 65536)

# Helper function to convert Q16.16 to float
def q16_16_to_float(value):
    return value / 65536.0

@cocotb.test()
async def test_geometric_sum_basic(dut):
    """Test basic geometric sum calculations"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=4, expected 1.9375
    expected_4 = 1.9375
    dut.n.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 10 cycles)
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result_4 = q16_16_to_float(int(dut.result.value))
    print(f"Test 1: n=4, Expected={expected_4:.6f}, Got={result_4:.6f}")
    assert abs(result_4 - expected_4) < 0.0001, f"Expected {expected_4}, got {result_4}"
    
    # Reset for next test
    await RisingEdge(dut.clk)
    
    # Test case 2: n=7, expected 1.9921875
    expected_7 = 1.9921875
    dut.n.value = 7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result_7 = q16_16_to_float(int(dut.result.value))
    print(f"Test 2: n=7, Expected={expected_7:.6f}, Got={result_7:.6f}")
    assert abs(result_7 - expected_7) < 0.0001, f"Expected {expected_7}, got {result_7}"
    
    # Reset for next test
    await RisingEdge(dut.clk)
    
    # Test case 3: n=8, expected 1.99609375
    expected_8 = 1.99609375
    dut.n.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result_8 = q16_16_to_float(int(dut.result.value))
    print(f"Test 3: n=8, Expected={expected_8:.6f}, Got={result_8:.6f}")
    assert abs(result_8 - expected_8) < 0.0001, f"Expected {expected_8}, got {result_8}"
    
    print(f"
All tests passed!")

@cocotb.test()
async def test_geometric_sum_edge_cases(dut):
    """Test edge cases for geometric sum"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 4: n=0, expected 0
    expected_0 = 0.0
    dut.n.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result_0 = q16_16_to_float(int(dut.result.value))
    print(f"Test 4: n=0, Expected={expected_0:.6f}, Got={result_0:.6f}")
    assert abs(result_0 - expected_0) < 0.0001, f"Expected {expected_0}, got {result_0}"
    
    # Reset for next test
    await RisingEdge(dut.clk)
    
    # Test case 5: n=1, expected 1.0
    expected_1 = 1.0
    dut.n.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result_1 = q16_16_to_float(int(dut.result.value))
    print(f"Test 5: n=1, Expected={expected_1:.6f}, Got={result_1:.6f}")
    assert abs(result_1 - expected_1) < 0.0001, f"Expected {expected_1}, got {result_1}"
    
    # Reset for next test
    await RisingEdge(dut.clk)
    
    # Test case 6: n=2, expected 1.5
    expected_2 = 1.5
    dut.n.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result_2 = q16_16_to_float(int(dut.result.value))
    print(f"Test 6: n=2, Expected={expected_2:.6f}, Got={result_2:.6f}")
    assert abs(result_2 - expected_2) < 0.0001, f"Expected {expected_2}, got {result_2}"
    
    print(f"
All edge case tests passed!")

@cocotb.test()
async def test_geometric_sum_reset(dut):
    """Test that reset properly clears state"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Start a computation
    dut.n.value = 7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Let it run for a few cycles, then reset
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Assert reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Check that done is low and result is zero
    assert dut.done.value == 0, "Done should be low after reset"
    assert int(dut.result.value) == 0, "Result should be zero after reset"
    
    print("Reset test passed!")
