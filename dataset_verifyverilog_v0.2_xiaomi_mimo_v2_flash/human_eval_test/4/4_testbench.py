import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

# Q16.16 conversion utilities
def float_to_q16_16(x):
    return int(x * 65536)

def q16_16_to_float(x):
    return x / 65536.0

@cocotb.test()
async def test_mad_basic(dut):
    """Test MAD calculation with 3 numbers"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_elements.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: [1.0, 2.0, 3.0] -> MAD = 2/3 = 0.6666667
    # Mean = 2.0, Deviations = [1.0, 0.0, 1.0], Sum = 2.0, MAD = 0.6666667
    inputs = [1.0, 2.0, 3.0]
    expected = 2.0 / 3.0
    
    # Start computation
    dut.start.value = 1
    dut.num_elements.value = len(inputs)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed data as requested
    data_index = 0
    for _ in range(100):  # Max cycles to wait
        await RisingEdge(dut.clk)
        if dut.read_index.value.is_resolvable and data_index < len(inputs):
            dut.data_in.value = float_to_q16_16(inputs[data_index])
            dut.data_valid.value = 1
            data_index += 1
        else:
            dut.data_valid.value = 0
        
        if dut.done.value:
            break
    
    result_float = q16_16_to_float(int(dut.result.value))
    print(f"Test 1 - Input: {inputs}, Expected: {expected:.6f}, Got: {result_float:.6f}")
    assert abs(result_float - expected) < 0.001, f"Expected {expected}, got {result_float}"

@cocotb.test()
async def test_mad_four_numbers(dut):
    """Test MAD calculation with 4 numbers"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_elements.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: [1.0, 2.0, 3.0, 4.0] -> MAD = 1.0
    # Mean = 2.5, Deviations = [1.5, 0.5, 0.5, 1.5], Sum = 4.0, MAD = 1.0
    inputs = [1.0, 2.0, 3.0, 4.0]
    expected = 1.0
    
    dut.start.value = 1
    dut.num_elements.value = len(inputs)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    data_index = 0
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.read_index.value.is_resolvable and data_index < len(inputs):
            dut.data_in.value = float_to_q16_16(inputs[data_index])
            dut.data_valid.value = 1
            data_index += 1
        else:
            dut.data_valid.value = 0
        
        if dut.done.value:
            break
    
    result_float = q16_16_to_float(int(dut.result.value))
    print(f"Test 2 - Input: {inputs}, Expected: {expected:.6f}, Got: {result_float:.6f}")
    assert abs(result_float - expected) < 0.001, f"Expected {expected}, got {result_float}"

@cocotb.test()
async def test_mad_five_numbers(dut):
    """Test MAD calculation with 5 numbers"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_elements.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: [1.0, 2.0, 3.0, 4.0, 5.0] -> MAD = 6/5 = 1.2
    # Mean = 3.0, Deviations = [2.0, 1.0, 0.0, 1.0, 2.0], Sum = 6.0, MAD = 1.2
    inputs = [1.0, 2.0, 3.0, 4.0, 5.0]
    expected = 6.0 / 5.0
    
    dut.start.value = 1
    dut.num_elements.value = len(inputs)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    data_index = 0
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.read_index.value.is_resolvable and data_index < len(inputs):
            dut.data_in.value = float_to_q16_16(inputs[data_index])
            dut.data_valid.value = 1
            data_index += 1
        else:
            dut.data_valid.value = 0
        
        if dut.done.value:
            break
    
    result_float = q16_16_to_float(int(dut.result.value))
    print(f"Test 3 - Input: {inputs}, Expected: {expected:.6f}, Got: {result_float:.6f}")
    assert abs(result_float - expected) < 0.001, f"Expected {expected}, got {result_float}"

@cocotb.test()
async def test_mad_single_element(dut):
    """Test MAD with single element (should be 0)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_elements.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    inputs = [5.0]
    expected = 0.0
    
    dut.start.value = 1
    dut.num_elements.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    data_index = 0
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.read_index.value.is_resolvable and data_index < len(inputs):
            dut.data_in.value = float_to_q16_16(inputs[data_index])
            dut.data_valid.value = 1
            data_index += 1
        else:
            dut.data_valid.value = 0
        
        if dut.done.value:
            break
    
    result_float = q16_16_to_float(int(dut.result.value))
    print(f"Test 4 - Input: {inputs}, Expected: {expected:.6f}, Got: {result_float:.6f}")
    assert abs(result_float - expected) < 0.001, f"Expected {expected}, got {result_float}"

@cocotb.test()
async def test_mad_zero_values(dut):
    """Test MAD with all zeros"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_elements.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    inputs = [0.0, 0.0, 0.0, 0.0]
    expected = 0.0
    
    dut.start.value = 1
    dut.num_elements.value = len(inputs)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    data_index = 0
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.read_index.value.is_resolvable and data_index < len(inputs):
            dut.data_in.value = float_to_q16_16(inputs[data_index])
            dut.data_valid.value = 1
            data_index += 1
        else:
            dut.data_valid.value = 0
        
        if dut.done.value:
            break
    
    result_float = q16_16_to_float(int(dut.result.value))
    print(f"Test 5 - Input: {inputs}, Expected: {expected:.6f}, Got: {result_float:.6f}")
    assert abs(result_float - expected) < 0.001, f"Expected {expected}, got {result_float}"
