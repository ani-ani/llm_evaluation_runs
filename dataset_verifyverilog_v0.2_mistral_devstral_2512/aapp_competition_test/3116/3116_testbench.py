import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random
import math

# Helper to convert float to Q16.16 fixed point integer
def float_to_q16_16(f):
    return int(f * 65536) & 0xFFFFFFFF

# Helper to convert Q16.16 to float
def q16_16_to_float(q):
    if q & 0x80000000:  # Sign bit set, negative number
        return -((~q + 1) / 65536.0)
    return q / 65536.0

@cocotb.test()
async def test_min_cylinder_volume(dut):
    """Test the min_cylinder_volume module with various point sets."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_points.value = 0
    for i in range(8):
        dut.points[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: 4 points (Example 1)
    points1 = [
        (1.0, 0.0, 0.0),
        (1.0, 1.0, 0.0),
        (0.0, 0.0, 0.0),
        (0.0, 0.0, 1.0)
    ]
    
    # Test Case 2: 4 points (Example 2)
    points2 = [
        (-100.0, 0.0, 0.0),
        (10.0, 0.0, 10.0),
        (-10.0, -10.0, -10.0),
        (0.0, 0.0, 0.0)
    ]

    # Select test case
    current_points = points1
    expected_vol = 1.57079633
    
    # Load inputs
    dut.num_points.value = 4
    for i, (x, y, z) in enumerate(current_points):
        # Construct 64-bit value: z (31:0), y (63:32) - Assuming little endian mapping in packed array or just raw bits
        # In Verilog [63:0] points [0:7], let's assume we pack as {x, y, z} or similar. 
        # The prompt specifies '3x 16-bit fixed-point'. Let's pack as: upper 16=x, middle 16=y, lower 16=z
        val_x = float_to_q16_16(x)
        val_y = float_to_q16_16(y)
        val_z = float_to_q16_16(z)
        packed = (val_x << 32) | (val_y << 16) | val_z
        dut.points[i].value = packed
    
    # Fill rest with 0
    for i in range(4, 8):
        dut.points[i].value = 0

    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    timeout = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 5000: # Safety timeout
            dut._log.error("Timeout waiting for done signal")
            assert False

    # Read result
    result_raw = int(dut.min_volume.value)
    result_float = q16_16_to_float(result_raw)
    
    dut._log.info(f"Expected Volume: {expected_vol}")
    dut._log.info(f"Computed Volume: {result_float}")
    
    # Check with relative tolerance
    assert abs(result_float - expected_vol) / expected_vol < 1e-4, f"Volume mismatch: {result_float} vs {expected_vol}"

    # --- Test Case 2 ---
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    current_points = points2
    expected_vol = 41938.65135885
    
    dut.num_points.value = 4
    for i, (x, y, z) in enumerate(current_points):
        val_x = float_to_q16_16(x)
        val_y = float_to_q16_16(y)
        val_z = float_to_q16_16(z)
        packed = (val_x << 32) | (val_y << 16) | val_z
        dut.points[i].value = packed
    
    for i in range(4, 8):
        dut.points[i].value = 0

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 5000:
            dut._log.error("Timeout waiting for done signal")
            assert False

    result_raw = int(dut.min_volume.value)
    result_float = q16_16_to_float(result_raw)
    
    dut._log.info(f"Expected Volume 2: {expected_vol}")
    dut._log.info(f"Computed Volume 2: {result_float}")
    
    assert abs(result_float - expected_vol) / expected_vol < 1e-4, f"Volume mismatch: {result_float} vs {expected_vol}"
