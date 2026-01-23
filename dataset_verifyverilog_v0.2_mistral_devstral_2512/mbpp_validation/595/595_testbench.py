import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_min_swaps(dut):
    """Test minimum swap calculation for binary strings"""
    
    # Test case helper function
    async def test_case(str1_val, str2_val, length_val, expected_swaps, expected_possible, description):
        dut.str1.value = str1_val
        dut.str2.value = str2_val
        dut.length.value = length_val
        await Timer(10, units='ns')
        
        actual_swaps = int(dut.swaps.value)
        actual_possible = int(dut.possible.value)
        
        assert actual_swaps == expected_swaps, f"{description}: Expected swaps={expected_swaps}, got {actual_swaps}"
        assert actual_possible == expected_possible, f"{description}: Expected possible={expected_possible}, got {actual_possible}"
        print(f"✓ Test '{description}': str1=0b{str1_val:016b}, str2=0b{str2_val:016b}, length={length_val} -> swaps={actual_swaps}, possible={actual_possible}")
    
    # Test 1: 1101 -> 1110 (1 swap needed, 2 mismatches)
    # str1=0b1101, str2=0b1110, length=4
    # Mismatches at bit 0 and bit 3 (from LSB) = 2 mismatches
    await test_case(0b1101, 0b1110, 4, 1, 1, "Test 1: 1101 to 1110")
    
    # Test 2: 111 -> 000 (3 mismatches, odd, impossible)
    # str1=0b111, str2=0b000, length=3
    await test_case(0b111, 0b000, 3, 0, 0, "Test 2: 111 to 000")
    
    # Test 3: 111 -> 110 (1 mismatch, odd, impossible)
    # str1=0b111, str2=0b110, length=3
    await test_case(0b111, 0b110, 3, 0, 0, "Test 3: 111 to 110")
    
    # Additional test cases
    # Test 4: Same strings (0 swaps)
    await test_case(0b1101, 0b1101, 4, 0, 1, "Test 4: Same strings")
    
    # Test 5: Complete swap required (4 mismatches, even)
    # 1010 -> 0101 (bits 0,1,2,3 all different)
    await test_case(0b1010, 0b0101, 4, 2, 1, "Test 5: 1010 to 0101")
    
    # Test 6: Single bit length (1 mismatch -> impossible)
    await test_case(0b1, 0b0, 1, 0, 0, "Test 6: Single bit mismatch")
    
    # Test 7: Single bit same (0 swaps)
    await test_case(0b1, 0b1, 1, 0, 1, "Test 7: Single bit same")
    
    # Test 8: 8-bit test with 4 mismatches (max swaps for 8 bits = 4)
    await test_case(0b11110000, 0b00001111, 8, 4, 1, "Test 8: 8-bit full swap")
    
    # Test 9: Large length, all different, even count
    await test_case(0xFFFFFFFF, 0x00000000, 16, 8, 1, "Test 9: All 16 bits different")
    
    # Test 10: Edge case - 15 mismatches (odd)
    # 0x7FFF vs 0x8000 gives 16 bits but differs in 16 positions
    # Let's do 15 bit length with all different = 15 mismatches
    await test_case(0x7FFF, 0x0000, 15, 0, 0, "Test 10: 15 mismatches (odd)")
    
    # Test 11: Two bits set, both need swapping (2 mismatches)
    # 1000 -> 0100 in 4 bits
    await test_case(0b1000, 0b0100, 4, 1, 1, "Test 11: 1000 to 0100")
    
    # Test 12: 6 mismatches (even, 3 swaps)
    await test_case(0b111000, 0b000111, 6, 3, 1, "Test 12: 111000 to 000111")
    
    print("
All tests passed!")