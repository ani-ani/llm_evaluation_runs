import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point format"""
    return int(value * 65536) & 0xFFFFFFFF

def q16_16_to_float(value):
    """Convert Q16.16 fixed-point to float"""
    if value >= 0x80000000:
        value = value - 0x100000000
    return value / 65536.0

@cocotb.test()
async def test_max_clique_basic(dut):
    """Test basic 4-sensor case with d=1.0"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 1: 4 sensors at (0,0), (0,1), (1,0), (1,1) with d=1.0
    # Expected: clique of size 2 (adjacent points)
    dut.n.value = 4
    dut.d.value = float_to_q16_16(1.0)
    
    # Set coordinates
    coords = [(0,0), (0,1), (1,0), (1,1)]
    for i, (x, y) in enumerate(coords):
        dut.x_coords[i].value = float_to_q16_16(x)
        dut.y_coords[i].value = float_to_q16_16(y)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 600:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 600, "Computation timed out"
    assert dut.done.value == 1, "Done signal not asserted"
    
    # Check result
    size = int(dut.size.value)
    print(f"Test 1: Clique size = {size}")
    print(f"Indices: {[int(dut.sensor_indices[i].value) for i in range(8)]}")
    
    assert size == 2, f"Expected size 2, got {size}"
    
    # Verify all indices are valid (1-4) and unique
    indices = [int(dut.sensor_indices[i].value) for i in range(size)]
    assert all(1 <= idx <= 4 for idx in indices), f"Invalid indices: {indices}"
    assert len(set(indices)) == size, f"Duplicate indices: {indices}"
    
    print("Test 1 PASSED")
    
    # Test Case 2: 5 sensors with d=20 (converted to Q16.16)
    await Timer(100, units='ns')
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    dut.n.value = 5
    dut.d.value = float_to_q16_16(20.0)
    
    coords2 = [(0,0), (0,2), (100,100), (100,110), (100,120)]
    for i, (x, y) in enumerate(coords2):
        dut.x_coords[i].value = float_to_q16_16(x)
        dut.y_coords[i].value = float_to_q16_16(y)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 0
    while not dut.done.value and timeout < 600:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 600, "Computation timed out"
    assert dut.done.value == 1, "Done signal not asserted"
    
    size2 = int(dut.size.value)
    print(f"Test 2: Clique size = {size2}")
    print(f"Indices: {[int(dut.sensor_indices[i].value) for i in range(8)]}")
    
    # Expected: sensors 3,4,5 are close (distance ≤20), so size 3
    # Distance between (100,100) and (100,110) = 10, (100,110) and (100,120) = 10
    # (100,100) and (100,120) = 20
    assert size2 == 3, f"Expected size 3, got {size2}"
    
    indices2 = [int(dut.sensor_indices[i].value) for i in range(size2)]
    assert all(1 <= idx <= 5 for idx in indices2), f"Invalid indices: {indices2}"
    assert len(set(indices2)) == size2, f"Duplicate indices: {indices2}"
    
    print("Test 2 PASSED")
    
    # Test Case 3: Single sensor
    await Timer(100, units='ns')
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    dut.n.value = 1
    dut.d.value = float_to_q16_16(5.0)
    dut.x_coords[0].value = float_to_q16_16(123)
    dut.y_coords[0].value = float_to_q16_16(456)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 600:
        await RisingEdge(dut.clk)
        timeout += 1
    
    size3 = int(dut.size.value)
    assert size3 == 1, f"Single sensor test failed: size={size3}"
    assert int(dut.sensor_indices[0].value) == 1, "First sensor index should be 1"
    print("Test 3 PASSED")
    
    # Test Case 4: All sensors connected (dense graph)
    await Timer(100, units='ns')
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    dut.n.value = 3
    dut.d.value = float_to_q16_16(100.0)
    
    # Three sensors at (0,0), (5,5), (10,10) - all within 100 units
    dut.x_coords[0].value = float_to_q16_16(0)
    dut.y_coords[0].value = float_to_q16_16(0)
    dut.x_coords[1].value = float_to_q16_16(5)
    dut.y_coords[1].value = float_to_q16_16(5)
    dut.x_coords[2].value = float_to_q16_16(10)
    dut.y_coords[2].value = float_to_q16_16(10)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 600:
        await RisingEdge(dut.clk)
        timeout += 1
    
    size4 = int(dut.size.value)
    assert size4 == 3, f"Fully connected graph test failed: size={size4}"
    print("Test 4 PASSED")
    
    # Test Case 5: All disconnected
    await Timer(100, units='ns')
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    dut.n.value = 4
    dut.d.value = float_to_q16_16(1.0)
    
    # Four sensors far apart
    dut.x_coords[0].value = float_to_q16_16(0)
    dut.y_coords[0].value = float_to_q16_16(0)
    dut.x_coords[1].value = float_to_q16_16(100)
    dut.y_coords[1].value = float_to_q16_16(0)
    dut.x_coords[2].value = float_to_q16_16(0)
    dut.y_coords[2].value = float_to_q16_16(100)
    dut.x_coords[3].value = float_to_q16_16(100)
    dut.y_coords[3].value = float_to_q16_16(100)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 600:
        await RisingEdge(dut.clk)
        timeout += 1
    
    size5 = int(dut.size.value)
    assert size5 == 1, f"Disconnected graph test failed: size={size5}"
    print("Test 5 PASSED")
    
    print("
All 5 tests passed!")