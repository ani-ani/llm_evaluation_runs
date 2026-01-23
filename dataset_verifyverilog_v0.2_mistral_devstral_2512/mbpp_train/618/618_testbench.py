import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_elementwise_div(dut):
    """Test element-wise division of 4-element arrays"""
    
    # Test 1: [4, 5, 6] / [1, 2, 3] = [4, 2, 2] with remainders [0, 1, 0]
    # 4/1 = 4 rem 0
    # 5/2 = 2 rem 1
    # 6/3 = 2 rem 0
    dut.num1_array.value = 0b0100_0101_0110  # [6, 5, 4] - note: bit concatenation order
    dut.num2_array.value = 0b0001_0010_0011  # [3, 2, 1]
    await Timer(10, units='ns')
    
    # In Verilog, we need to match bit ordering
    # Let's test individual elements with correct ordering
    
    # Reset to known values
    dut.num1_array.value = 0
    dut.num2_array.value = 0
    await Timer(5, units='ns')
    
    # Test case 1: 4/1, 5/2, 6/3
    # Element 0: 4/1
    # Element 1: 5/2  
    # Element 2: 6/3
    # For 4-element array, let's use positions [3:0] for each element
    
    # Actual test with properly ordered bits
    # We'll test each element separately for clarity
    
    # Test: nums1=[4,5,6,0], nums2=[1,2,3,1]
    # This requires 4 elements: element 0=4/1, element 1=5/2, element 2=6/3, element 3=0/1
    
    # Simulating proper bit assignment:
    # num1_array[3:0] = first element, [7:4] = second, etc.
    # But input is 4 bits total, meaning 1 bit per element? Let's re-read.
    
    # Re-interpreting: 4 elements, each element is 4 bits
    # So num1_array[3:0] is element 0, num1_array[7:4] is element 1, etc.
    # Total width = 4*4 = 16 bits
    
    # Test 1: [4,5,6,0] / [1,2,3,1]
    # Element 0: 4'b0100 / 4'b0001 = 4'b0100
    # Element 1: 4'b0101 / 4'b0010 = 4'b0010  
    # Element 2: 4'b0110 / 4'b0011 = 4'b0010
    # Element 3: 4'b0000 / 4'b0001 = 4'b0000
    # Quotient array: {4'b0000, 4'b0010, 4'b0010, 4'b0100} = 16'h0022_4
    # Remainder array: {4'b0000, 4'b0001, 4'b0001, 4'b0000} = 16'h0011_0
    
    dut.num1_array.value = 0b0000_0110_0101_0100  # [0,6,5,4] - reversed element order
    dut.num2_array.value = 0b0001_0011_0010_0001  # [1,3,2,1]
    await Timer(10, units='ns')
    
    # Expected: quotient = [4,2,2,0], remainder = [0,1,1,0]
    expected_quotient = 0b0000_0010_0010_0100
    expected_remainder = 0b0000_0001_0001_0000
    
    assert dut.quotient_array.value == expected_quotient, f"Test 1 failed: expected {expected_quotient:b}, got {dut.quotient_array.value:b}"
    assert dut.remainder_array.value == expected_remainder, f"Test 1 failed: expected {expected_remainder:b}, got {dut.remainder_array.value:b}"
    
    # Test 2: [3,2,0,0] / [1,4,1,1] = [3,0,0,0] with remainders [0,2,0,0]
    # Element 0: 3/1 = 3 rem 0
    # Element 1: 2/4 = 0 rem 2  
    # Element 2: 0/1 = 0 rem 0
    # Element 3: 0/1 = 0 rem 0
    dut.num1_array.value = 0b0000_0000_0010_0011  # [0,0,2,3]
    dut.num2_array.value = 0b0001_0001_0100_0001  # [1,1,4,1]
    await Timer(10, units='ns')
    
    expected_quotient = 0b0000_0000_0000_0011
    expected_remainder = 0b0000_0000_0010_0000
    
    assert dut.quotient_array.value == expected_quotient, f"Test 2 failed: expected {expected_quotient:b}, got {dut.quotient_array.value:b}"
    assert dut.remainder_array.value == expected_remainder, f"Test 2 failed: expected {expected_remainder:b}, got {dut.remainder_array.value:b}"
    
    # Test 3: [10, 12, 0, 0] / [5, 7, 1, 1] = [2, 1, 0, 0] with remainders [0, 5, 0, 0]
    # Note: 90 and 120 exceed 4-bit range, so we use 10 and 12
    # Element 0: 10/5 = 2 rem 0
    # Element 1: 12/7 = 1 rem 5
    # Element 2: 0/1 = 0 rem 0
    # Element 3: 0/1 = 0 rem 0
    dut.num1_array.value = 0b0000_0000_1100_1010  # [0,0,12,10]
    dut.num2_array.value = 0b0001_0001_0111_0101  # [1,1,7,5]
    await Timer(10, units='ns')
    
    expected_quotient = 0b0000_0000_0001_0010
    expected_remainder = 0b0000_0000_0000_0000
    
    assert dut.quotient_array.value == expected_quotient, f"Test 3 failed: expected {expected_quotient:b}, got {dut.quotient_array.value:b}"
    assert dut.remainder_array.value == expected_remainder, f"Test 3 failed: expected {expected_remainder:b}, got {dut.remainder_array.value:b}"
    
    # Test 4: Division by zero handling
    # Element 0: 5/0 = saturate to 15, remainder 0
    dut.num1_array.value = 0b0000_0000_0000_0101  # [0,0,0,5]
    dut.num2_array.value = 0b0000_0000_0000_0000  # [0,0,0,0]
    await Timer(10, units='ns')
    
    expected_quotient = 0b0000_0000_0000_1111  # 15 for division by zero
    expected_remainder = 0b0000_0000_0000_0000
    
    assert dut.quotient_array.value == expected_quotient, f"Test 4 failed: expected {expected_quotient:b}, got {dut.quotient_array.value:b}"
    assert dut.remainder_array.value == expected_remainder, f"Test 4 failed: expected {expected_remainder:b}, got {dut.remainder_array.value:b}"
    
    # Test 5: Maximum values
    # Element 0: 15/1 = 15 rem 0
    # Element 1: 15/15 = 1 rem 0
    # Element 2: 14/2 = 7 rem 0
    # Element 3: 13/3 = 4 rem 1
    dut.num1_array.value = 0b1111_1111_1110_1101  # [15,15,14,13]
    dut.num2_array.value = 0b0001_1111_0010_0011  # [1,15,2,3]
    await Timer(10, units='ns')
    
    expected_quotient = 0b1111_0001_0111_0100  # [15,1,7,4]
    expected_remainder = 0b0000_0000_0000_0001  # [0,0,0,1]
    
    assert dut.quotient_array.value == expected_quotient, f"Test 5 failed: expected {expected_quotient:b}, got {dut.quotient_array.value:b}"
    assert dut.remainder_array.value == expected_remainder, f"Test 5 failed: expected {expected_remainder:b}, got {dut.remainder_array.value:b}"
    
    print("All 5 tests passed!")