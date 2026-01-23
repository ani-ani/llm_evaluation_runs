import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

# Helper to convert signed 16-bit integer (Python) to verilog format (handles negative)
def to_signed_16(val):
    if val < 0:
        return (1 << 16) + val
    return val

@cocotb.test()
async def test_protest_location(dut):
    """Test the protest location finder module"""
    
    # Helper function to run a test case
    async def run_test(citizens, d, expected_output, test_name):
        # Set inputs
        dut.num_citizens.value = len(citizens)
        dut.d_max.value = to_signed_16(d)
        
        # Reset coordinates to 0 (or some default) for unused slots
        # We need to map the list of citizens to the 8 inputs
        coords_flat = []
        for i in range(8):
            if i < len(citizens):
                coords_flat.append(citizens[i][0]) # x
                coords_flat.append(citizens[i][1]) # y
            else:
                coords_flat.append(0)
                coords_flat.append(0)
        
        dut.x0.value = to_signed_16(coords_flat[0])
        dut.y0.value = to_signed_16(coords_flat[1])
        dut.x1.value = to_signed_16(coords_flat[2])
        dut.y1.value = to_signed_16(coords_flat[3])
        dut.x2.value = to_signed_16(coords_flat[4])
        dut.y2.value = to_signed_16(coords_flat[5])
        dut.x3.value = to_signed_16(coords_flat[6])
        dut.y3.value = to_signed_16(coords_flat[7])
        dut.x4.value = to_signed_16(coords_flat[8])
        dut.y4.value = to_signed_16(coords_flat[9])
        dut.x5.value = to_signed_16(coords_flat[10])
        dut.y5.value = to_signed_16(coords_flat[11])
        dut.x6.value = to_signed_16(coords_flat[12])
        dut.y6.value = to_signed_16(coords_flat[13])
        dut.x7.value = to_signed_16(coords_flat[14])
        dut.y7.value = to_signed_16(coords_flat[15])
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read outputs
        got_valid = int(dut.valid.value)
        got_dist = int(dut.min_total_distance.value)
        
        if expected_output == "impossible":
            assert got_valid == 0, f"{test_name}: Expected impossible (valid=0), got {got_valid}"
        else:
            expected = int(expected_output)
            assert got_valid == 1, f"{test_name}: Expected valid=1, got {got_valid}"
            assert got_dist == expected, f"{test_name}: Expected {expected}, got {got_dist}"
    
    # --- Scaled Test Cases ---
    
    # Original Test 1:
    # Citizens: (3,1), (4,1), (5,9), (2,6), (5,3). d=10. Output=18.
    # These coordinates fit within 16-bit signed range.
    await run_test(
        [(3,1), (4,1), (5,9), (2,6), (5,3)],
        10,
        18,
        "Case 1: d=10"
    )
    
    # Original Test 2:
    # Same citizens, d=5. Output=20.
    await run_test(
        [(3,1), (4,1), (5,9), (2,6), (5,3)],
        5,
        20,
        "Case 2: d=5"
    )
    
    # Original Test 3:
    # Same citizens, d=4. Output=impossible.
    await run_test(
        [(3,1), (4,1), (5,9), (2,6), (5,3)],
        4,
        "impossible",
        "Case 3: d=4 (Impossible)"
    )
    
    # Additional Test 4: Trivial case (2 citizens)
    # (0,0) and (10,10). d=20.
    # Optimal is (0,10) or (10,0) or (5,5) - all give 20.
    # Our grid search will pick one of these.
    await run_test(
        [(0,0), (10,10)],
        20,
        20,
        "Case 4: Two points"
    )

    # Additional Test 5: Exact center
    # (0,0) and (10,0). d=5. Optimal is (5,0). Total dist = 5+5=10.
    await run_test(
        [(0,0), (10,0)],
        5,
        10,
        "Case 5: Line"
    )

    print("All tests passed!")
