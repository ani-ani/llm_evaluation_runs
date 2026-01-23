import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper to convert decimal to Q8.8 fixed point
def to_q88(value):
    return int(value * 256)

# Helper to convert Q8.8 to decimal
def from_q88(value):
    return value / 256.0

@cocotb.test()
async def test_max_average_subarray(dut):
    """Test max average subarray module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write_en.value = 0
    dut.n.value = 0
    dut.k.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: [1, 2, 3, 4] N=4, K=1, Expected: 4.0
    print("
Test Case 1: [1, 2, 3, 4], N=4, K=1")
    dut.n.value = 4
    dut.k.value = 1
    
    # Load array
    for i, val in enumerate([1, 2, 3, 4]):
        dut.index.value = i
        dut.data_in.value = val
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 200, "Timeout waiting for done"
    assert dut.valid.value == 1, "Result should be valid"
    
    result = int(dut.result.value)
    result_decimal = from_q88(result)
    expected = 4.0
    
    print(f"Result: {result_decimal:.6f} (Q8.8: {result})")
    print(f"Expected: {expected:.6f}")
    print(f"Difference: {abs(result_decimal - expected):.6f}")
    
    assert abs(result_decimal - expected) < 0.01, f"Expected {expected}, got {result_decimal}"
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: [2, 4, 3, 4] N=4, K=2, Expected: 3.666666
    print("
Test Case 2: [2, 4, 3, 4], N=4, K=2")
    dut.n.value = 4
    dut.k.value = 2
    
    for i, val in enumerate([2, 4, 3, 4]):
        dut.index.value = i
        dut.data_in.value = val
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 200, "Timeout waiting for done"
    assert dut.valid.value == 1, "Result should be valid"
    
    result = int(dut.result.value)
    result_decimal = from_q88(result)
    expected = 3.666666
    
    print(f"Result: {result_decimal:.6f} (Q8.8: {result})")
    print(f"Expected: {expected:.6f}")
    print(f"Difference: {abs(result_decimal - expected):.6f}")
    
    assert abs(result_decimal - expected) < 0.01, f"Expected {expected}, got {result_decimal}"
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: [7, 1, 2, 1, 3, 6] N=6, K=3, Expected: 3.333333
    print("
Test Case 3: [7, 1, 2, 1, 3, 6], N=6, K=3")
    dut.n.value = 6
    dut.k.value = 3
    
    for i, val in enumerate([7, 1, 2, 1, 3, 6]):
        dut.index.value = i
        dut.data_in.value = val
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 200, "Timeout waiting for done"
    assert dut.valid.value == 1, "Result should be valid"
    
    result = int(dut.result.value)
    result_decimal = from_q88(result)
    expected = 3.333333
    
    print(f"Result: {result_decimal:.6f} (Q8.8: {result})")
    print(f"Expected: {expected:.6f}")
    print(f"Difference: {abs(result_decimal - expected):.6f}")
    
    assert abs(result_decimal - expected) < 0.01, f"Expected {expected}, got {result_decimal}"
    
    # Edge case: All same values
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
Test Case 4: [5, 5, 5, 5], N=4, K=3")
    dut.n.value = 4
    dut.k.value = 3
    
    for i, val in enumerate([5, 5, 5, 5]):
        dut.index.value = i
        dut.data_in.value = val
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
    
    dut.write_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result = int(dut.result.value)
    result_decimal = from_q88(result)
    expected = 5.0
    
    print(f"Result: {result_decimal:.6f}")
    print(f"Expected: {expected:.6f}")
    
    assert abs(result_decimal - expected) < 0.01
    
    print("
=== Summary: All 4 tests passed ===")