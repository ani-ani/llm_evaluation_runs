import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_cube_nums(dut):
    """Test element-wise cubing of an array."""
    
    # Test Case 1: Mixed values from the original problem
    # 1->1, 2->8, 3->27, ..., 10->1000
    # We map these to the first 10 indices of the 16-element input array
    input_vals_1 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 0, 0, 0, 0, 0, 0]
    expected_1 = [1, 8, 27, 64, 125, 216, 343, 512, 729, 1000, 0, 0, 0, 0, 0, 0]
    
    # Set input signals
    for i in range(16):
        dut.nums_in[i].value = input_vals_1[i]
    
    # Wait a small amount of time for combinational logic to settle
    await Timer(10, units='ns')
    
    # Check outputs
    for i in range(16):
        actual = int(dut.cubes_out[i].value)
        assert actual == expected_1[i], f"Test 1 Index {i}: Expected {expected_1[i]}, got {actual}"
    
    print(f"Test 1 passed: Cubes of {input_vals_1[:10]}... verified")

    # Test Case 2: Larger values
    input_vals_2 = [10, 20, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    expected_2 = [1000, 8000, 27000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    for i in range(16):
        dut.nums_in[i].value = input_vals_2[i]
    
    await Timer(10, units='ns')
    
    for i in range(16):
        actual = int(dut.cubes_out[i].value)
        assert actual == expected_2[i], f"Test 2 Index {i}: Expected {expected_2[i]}, got {actual}"

    print(f"Test 2 passed: Cubes of {input_vals_2[:3]}... verified")

    # Test Case 3: Small values
    input_vals_3 = [12, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    expected_3 = [1728, 3375, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    for i in range(16):
        dut.nums_in[i].value = input_vals_3[i]
    
    await Timer(10, units='ns')
    
    for i in range(16):
        actual = int(dut.cubes_out[i].value)
        assert actual == expected_3[i], f"Test 3 Index {i}: Expected {expected_3[i]}, got {actual}"

    print(f"Test 3 passed: Cubes of {input_vals_3[:2]}... verified")
    
    # Test Case 4: Max 8-bit input (255) -> 16,581,375
    input_vals_4 = [255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    expected_4 = [16581375, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    for i in range(16):
        dut.nums_in[i].value = input_vals_4[i]
        
    await Timer(10, units='ns')
    
    for i in range(16):
        actual = int(dut.cubes_out[i].value)
        assert actual == expected_4[i], f"Test 4 Index {i}: Expected {expected_4[i]}, got {actual}"

    print(f"Test 4 passed: Max value cube verified")
    print("All tests passed!")