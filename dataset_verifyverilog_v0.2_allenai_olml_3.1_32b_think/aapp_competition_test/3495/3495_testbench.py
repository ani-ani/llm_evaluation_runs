import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import math

# Helper functions for Q16.16 conversion
def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point representation"""
    return int(value * 65536) & 0xFFFFFFFF

def q16_16_to_float(value):
    """Convert Q16.16 fixed-point to float"""
    if value & 0x80000000:  # Negative number
        return (value - 0x100000000) / 65536.0
    return value / 65536.0

def q16_16_to_int_signed(value):
    """Convert Q16.16 to signed integer (for Verilog signed input)"""
    if value & 0x80000000:
        return value - 0x100000000
    return value

@cocotb.test()
async def test_robotic_arm_basic(dut):
    """Test basic robotic arm with 3 segments reaching to (5, 3)"""
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
    
    # Test case from problem: 3 segments [5, 3, 4], target (5, 3)
    dut.num_segments.value = 3
    dut.seg_length[0].value = float_to_q16_16(5.0)
    dut.seg_length[1].value = float_to_q16_16(3.0)
    dut.seg_length[2].value = float_to_q16_16(4.0)
    dut.target_x.value = float_to_q16_16(5.0)
    dut.target_y.value = float_to_q16_16(3.0)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 20 cycles for 8 segments, 3 should be faster)
    timeout = 0
    while not dut.done.value and timeout < 30:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 30:
        raise TestFailure("Timeout - computation did not complete")
    
    # Read results
    joint_x = [q16_16_to_float(int(dut.joint_x[i].value)) for i in range(3)]
    joint_y = [q16_16_to_float(int(dut.joint_y[i].value)) for i in range(3)]
    
    print(f"
Test 1 - Joint positions:")
    for i in range(3):
        print(f"  Joint {i+1}: ({joint_x[i]:.6f}, {joint_y[i]:.6f})")
    
    # Check segment lengths
    for i in range(3):
        if i == 0:
            dx = joint_x[i]
            dy = joint_y[i]
        else:
            dx = joint_x[i] - joint_x[i-1]
            dy = joint_y[i] - joint_y[i-1]
        
        length = math.sqrt(dx*dx + dy*dy)
        expected = [5.0, 3.0, 4.0][i]
        
        if abs(length - expected) > 0.1:
            raise TestFailure(f"Segment {i+1} length error: got {length:.6f}, expected {expected}")
    
    # Check final position is close to target
    final_x = joint_x[2]
    final_y = joint_y[2]
    dist_to_target = math.sqrt((final_x-5.0)**2 + (final_y-3.0)**2)
    
    if dist_to_target > 0.15:  # Allow small error for fixed-point
        raise TestFailure(f"Final position too far from target: distance {dist_to_target:.6f}")
    
    print(f"Test 1 PASSED: Distance to target = {dist_to_target:.6f}")

@cocotb.test()
async def test_robotic_arm_short_reach(dut):
    """Test with 2 segments that cannot reach target"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: 2 segments [4, 2], target (-8, -3)
    # Total length = 6, but distance to target = sqrt(64+9)=8.54 -> cannot reach
    dut.num_segments.value = 2
    dut.seg_length[0].value = float_to_q16_16(4.0)
    dut.seg_length[1].value = float_to_q16_16(2.0)
    dut.target_x.value = float_to_q16_16(-8.0)
    dut.target_y.value = float_to_q16_16(-3.0)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 0
    while not dut.done.value and timeout < 30:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 30:
        raise TestFailure("Timeout - computation did not complete")
    
    # Read results
    joint_x = [q16_16_to_float(int(dut.joint_x[i].value)) for i in range(2)]
    joint_y = [q16_16_to_float(int(dut.joint_y[i].value)) for i in range(2)]
    
    print(f"
Test 2 - Joint positions:")
    for i in range(2):
        print(f"  Joint {i+1}: ({joint_x[i]:.6f}, {joint_y[i]:.6f})")
    
    # Check segment lengths
    dx1 = joint_x[0]
    dy1 = joint_y[0]
    dx2 = joint_x[1] - joint_x[0]
    dy2 = joint_y[1] - joint_y[0]
    
    length1 = math.sqrt(dx1*dx1 + dy1*dy1)
    length2 = math.sqrt(dx2*dx2 + dy2*dy2)
    
    if abs(length1 - 4.0) > 0.1:
        raise TestFailure(f"Segment 1 length error: got {length1:.6f}, expected 4.0")
    if abs(length2 - 2.0) > 0.1:
        raise TestFailure(f"Segment 2 length error: got {length2:.6f}, expected 2.0")
    
    # Check that reachable flag is low
    if dut.reachable.value:
        raise TestFailure("Reachable flag should be low for unreachable target")
    
    # Check final position is along line to target
    target_mag = math.sqrt(8*8 + 3*3)
    expected_x = 6.0 * (-8.0 / target_mag)
    expected_y = 6.0 * (-3.0 / target_mag)
    
    final_x = joint_x[1]
    final_y = joint_y[1]
    
    print(f"Expected final: ({expected_x:.6f}, {expected_y:.6f})")
    print(f"Actual final: ({final_x:.6f}, {final_y:.6f})")
    
    dist_to_expected = math.sqrt((final_x-expected_x)**2 + (final_y-expected_y)**2)
    if dist_to_expected > 0.2:
        raise TestFailure(f"Final position not along target direction: error {dist_to_expected:.6f}")
    
    print(f"Test 2 PASSED: Final position along target direction")

@cocotb.test()
async def test_robotic_arm_origin_target(dut):
    """Test with target at origin"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: 2 segments [5, 5], target (0, 0)
    # Cannot reach exactly - arm extends to 10 units
    dut.num_segments.value = 2
    dut.seg_length[0].value = float_to_q16_16(5.0)
    dut.seg_length[1].value = float_to_q16_16(5.0)
    dut.target_x.value = 0
    dut.target_y.value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 0
    while not dut.done.value and timeout < 30:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 30:
        raise TestFailure("Timeout - computation did not complete")
    
    # Read results
    joint_x = [q16_16_to_float(int(dut.joint_x[i].value)) for i in range(2)]
    joint_y = [q16_16_to_float(int(dut.joint_y[i].value)) for i in range(2)]
    
    print(f"
Test 3 - Joint positions:")
    for i in range(2):
        print(f"  Joint {i+1}: ({joint_x[i]:.6f}, {joint_y[i]:.6f})")
    
    # Check segments
    dx1 = joint_x[0]
    dy1 = joint_y[0]
    dx2 = joint_x[1] - joint_x[0]
    dy2 = joint_y[1] - joint_y[0]
    
    length1 = math.sqrt(dx1*dx1 + dy1*dy1)
    length2 = math.sqrt(dx2*dx2 + dy2*dy2)
    
    if abs(length1 - 5.0) > 0.1 or abs(length2 - 5.0) > 0.1:
        raise TestFailure("Segment lengths incorrect")
    
    # Final position should be 10 units from origin
    final_dist = math.sqrt(joint_x[1]**2 + joint_y[1]**2)
    if abs(final_dist - 10.0) > 0.2:
        raise TestFailure(f"Final distance should be 10, got {final_dist:.6f}")
    
    if dut.reachable.value:
        raise TestFailure("Reachable flag should be low for origin target")
    
    print(f"Test 3 PASSED: Final distance = {final_dist:.6f}")

@cocotb.test()
async def test_robotic_arm_exact_reach(dut):
    """Test with target exactly reachable"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: 1 segment [10], target (10, 0)
    dut.num_segments.value = 1
    dut.seg_length[0].value = float_to_q16_16(10.0)
    dut.target_x.value = float_to_q16_16(10.0)
    dut.target_y.value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 0
    while not dut.done.value and timeout < 30:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 30:
        raise TestFailure("Timeout - computation did not complete")
    
    # Read results
    joint_x = q16_16_to_float(int(dut.joint_x[0].value))
    joint_y = q16_16_to_float(int(dut.joint_y[0].value))
    
    print(f"
Test 4 - Joint position: ({joint_x:.6f}, {joint_y:.6f})")
    
    # Check it's at target
    if abs(joint_x - 10.0) > 0.1 or abs(joint_y) > 0.1:
        raise TestFailure(f"Joint not at target: got ({joint_x:.6f}, {joint_y:.6f})")
    
    if not dut.reachable.value:
        raise TestFailure("Reachable flag should be high")
    
    print(f"Test 4 PASSED: Reached target exactly")

print("
=== Summary ===")
print("All 4 test cases designed to verify:")
print("1. Basic reachability with 3 segments")
print("2. Unreachable target - arm extends to max")
print("3. Target at origin")
print("4. Exact single segment reach")
