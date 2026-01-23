import cocotb
from cocotb.triggers import Timer
import math

# Helper to convert float to Q16.16 fixed point
def to_q16_16(value):
    return int(value * 65536) & 0xFFFF

# Helper to convert Q16.16 to float
def to_float(q):
    if q & 0x8000: # Negative number (if we were using 2's complement, but here we use positive only for simplicity in this specific problem context or handle signed inputs separately)
        # Assuming inputs are positive for this specific problem context
        return q / 65536.0
    return q / 65536.0

@cocotb.test()
async def test_cat_chase(dut):
    # Initialize signals
    dut.valid_mice_mask.value = 0
    dut.x_coords.value = 0
    dut.y_coords.value = 0
    dut.deadlines.value = 0
    dut.velocities.value = 0
    
    await Timer(10, units='ns')
    
    # Test Case 1: 1 mouse, simple distance
    # Mouse 0: (3,4), dist=5, time=2. vel needed = 2.5. With .75 factor, only 1 step.
    # Sequence: vel=2.5
    dut.valid_mice_mask.value = 1 # Only mouse 0 active
    dut.x_coords[0].value = to_q16_16(3)
    dut.y_coords[0].value = to_q16_16(4)
    dut.deadlines[0].value = to_q16_16(2)
    dut.velocities[0].value = to_q16_16(2.5)
    
    await Timer(1, units='ns')
    assert dut.success.value == 1, "Test 1 Failed: Should be valid with v=2.5"
    print("Test 1 Passed")

    # Test Case 2: 2 mice, optimal order
    # Mice: 
    # 0: (0, 100), s=10
    # 1: (0, -100), s=100
    # Optimal order: 0 then 1
    # Dist 0 = 100. Vel 0 = 10. Time 0 = 10. (Fits exactly)
    # Vel 1 = 10 * 0.8 = 8. Dist 1 = 200. Time 1 = 200/8 = 25.
    # Total time = 35. Deadline 1 is 100. Fits.
    dut.valid_mice_mask.value = 3 # Mouse 0 and 1 active
    dut.x_coords[0].value = 0
    dut.y_coords[0].value = to_q16_16(100)
    dut.deadlines[0].value = to_q16_16(10)
    
    dut.x_coords[1].value = 0
    dut.y_coords[1].value = to_q16_16(-100) # Y is negative, abs logic needed or pre-abs inputs. Let's assume inputs are positive distances or we rely on Manhattan logic.
    # Note: Verilog spec said Manhattan distance |dx| + |dy|. 
    # For (0, -100), |0| + |-100| = 100. Wait, dist from 0,100 to 0,-100 is 200.
    # Let's refine Test 2 to be simpler: Cat starts at (0,0).
    # Mouse 0: (0, 100), s=10. Dist=100. Vel=10. Time=10. OK.
    # Mouse 1: (0, -100), s=100. Dist from (0,100) = 200. Vel=8. Time=25. Total 35. OK.
    # Manhattan logic: 
    # Step 0: (0,0) -> (0,100). |0|+|100| = 100.
    # Step 1: (0,100) -> (0,-100). |0|+|200| = 200. (Y diff = -200, abs 200).
    # However, in Verilog we need to handle coordinates. Let's assume the testbench provides absolute positions.
    # Verilog calculates |x_current - x_target| + |y_current - y_target|.
    # Start (0,0).
    # Target 0 (0, 100). dx=0, dy=100. Dist=100.
    # Target 1 (0, -100). dx=0, dy=200 (100 - (-100) = 200). Dist=200.
    
    dut.y_coords[1].value = 0x10000 * -100 # But Verilog input is reg [15:0]. We can't send negative easily in standard logic without signed extension. 
    # Constraint: Keep inputs positive or simple. 
    # Let's adjust the sequence to be purely positive coordinates to avoid signed complexity in inputs.
    # Test Case 2 (Revised):
    # Mouse 0: (0, 100), s=10
    # Mouse 1: (0, 200), s=100
    # Sequence: 0 then 1
    # Dist 0 = 100. Vel 0 = 10. Time 0 = 10. OK.
    # Dist 1 = 100. Vel 1 = 8. Time 1 = 12.5. Total 22.5. OK.
    
    dut.y_coords[1].value = to_q16_16(200)
    dut.deadlines[1].value = to_q16_16(100)
    dut.velocities[0].value = to_q16_16(10)
    dut.velocities[1].value = to_q16_16(8)
    
    await Timer(1, units='ns')
    assert dut.success.value == 1, "Test 2 Failed"
    print("Test 2 Passed")

    # Test Case 3: Failure case
    # Mouse 0: (0, 100), s=9 (Tight deadline)
    # Vel 0 = 10. Time 0 = 10. 10 > 9. Fail.
    dut.deadlines[0].value = to_q16_16(9)
    
    await Timer(1, units='ns')
    assert dut.success.value == 0, "Test 3 Failed: Should fail tight deadline"
    print("Test 3 Passed")
    
    print("All tests passed!")