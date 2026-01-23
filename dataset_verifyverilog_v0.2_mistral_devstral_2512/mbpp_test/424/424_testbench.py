import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_extract_rear(dut):
    """Test extract_rear module with multiple test cases"""
    
    # Test Case 1: ('Mers', 'for', 'Vers') -> ['s', 'r', 's']
    # 'Mers' = 0x4D657273, len=4, last='s'=0x73
    # 'for' = 0x666F7200, len=3, last='r'=0x72
    # 'Vers' = 0x56657273, len=4, last='s'=0x73
    dut.str1.value = 0x4D657273
    dut.str2.value = 0x666F7200
    dut.str3.value = 0x56657273
    dut.len1.value = 4
    dut.len2.value = 3
    dut.len3.value = 4
    await Timer(10, units='ns')
    
    assert dut.rear1.value == 0x73, f"Test 1 failed: expected 0x73 ('s'), got {hex(int(dut.rear1.value))}"
    assert dut.rear2.value == 0x72, f"Test 1 failed: expected 0x72 ('r'), got {hex(int(dut.rear2.value))}"
    assert dut.rear3.value == 0x73, f"Test 1 failed: expected 0x73 ('s'), got {hex(int(dut.rear3.value))}"
    print("Test 1 passed: ('Mers', 'for', 'Vers') -> ['s', 'r', 's']")
    
    # Test Case 2: ('Avenge', 'for', 'People') -> ['e', 'r', 'e']
    # 'Avenge' = 0x4176656E, len=6, last='e'=0x65
    # 'for' = 0x666F7200, len=3, last='r'=0x72
    # 'People' = 0x50656F6C, len=6, last='e'=0x65
    dut.str1.value = 0x4176656E
    dut.str2.value = 0x666F7200
    dut.str3.value = 0x50656F6C
    dut.len1.value = 6
    dut.len2.value = 3
    dut.len3.value = 6
    await Timer(10, units='ns')
    
    assert dut.rear1.value == 0x65, f"Test 2 failed: expected 0x65 ('e'), got {hex(int(dut.rear1.value))}"
    assert dut.rear2.value == 0x72, f"Test 2 failed: expected 0x72 ('r'), got {hex(int(dut.rear2.value))}"
    assert dut.rear3.value == 0x65, f"Test 2 failed: expected 0x65 ('e'), got {hex(int(dut.rear3.value))}"
    print("Test 2 passed: ('Avenge', 'for', 'People') -> ['e', 'r', 'e']")
    
    # Test Case 3: ('Gotta', 'get', 'go') -> ['a', 't', 'o']
    # 'Gotta' = 0x476F7474, len=5, last='a'=0x61
    # 'get' = 0x67657400, len=3, last='t'=0x74
    # 'go' = 0x676F0000, len=2, last='o'=0x6F
    dut.str1.value = 0x476F7474
    dut.str2.value = 0x67657400
    dut.str3.value = 0x676F0000
    dut.len1.value = 5
    dut.len2.value = 3
    dut.len3.value = 2
    await Timer(10, units='ns')
    
    assert dut.rear1.value == 0x61, f"Test 3 failed: expected 0x61 ('a'), got {hex(int(dut.rear1.value))}"
    assert dut.rear2.value == 0x74, f"Test 3 failed: expected 0x74 ('t'), got {hex(int(dut.rear2.value))}"
    assert dut.rear3.value == 0x6F, f"Test 3 failed: expected 0x6F ('o'), got {hex(int(dut.rear3.value))}"
    print("Test 3 passed: ('Gotta', 'get', 'go') -> ['a', 't', 'o']")
    
    # Edge case: Single character strings
    # 'X' = 0x58000000, len=1, last='X'=0x58
    # 'Y' = 0x59000000, len=1, last='Y'=0x59
    # 'Z' = 0x5A000000, len=1, last='Z'=0x5A
    dut.str1.value = 0x58000000
    dut.str2.value = 0x59000000
    dut.str3.value = 0x5A000000
    dut.len1.value = 1
    dut.len2.value = 1
    dut.len3.value = 1
    await Timer(10, units='ns')
    
    assert dut.rear1.value == 0x58, f"Edge case failed: expected 0x58 ('X'), got {hex(int(dut.rear1.value))}"
    assert dut.rear2.value == 0x59, f"Edge case failed: expected 0x59 ('Y'), got {hex(int(dut.rear2.value))}"
    assert dut.rear3.value == 0x5A, f"Edge case failed: expected 0x5A ('Z'), got {hex(int(dut.rear3.value))}"
    print("Edge case passed: single character strings")
    
    # Edge case: Maximum length (8 chars)
    # 'abcdefgh' = 0x6162636465666768, len=8, last='h'=0x68
    # '12345678' = 0x3132333435363738, len=8, last='8'=0x38
    # 'WXYZ1234' = 0x5758595A31323334, len=8, last='4'=0x34
    dut.str1.value = 0x6162636465666768
    dut.str2.value = 0x3132333435363738
    dut.str3.value = 0x5758595A31323334
    dut.len1.value = 8
    dut.len2.value = 8
    dut.len3.value = 8
    await Timer(10, units='ns')
    
    assert dut.rear1.value == 0x68, f"Max length test failed: expected 0x68 ('h'), got {hex(int(dut.rear1.value))}"
    assert dut.rear2.value == 0x38, f"Max length test failed: expected 0x38 ('8'), got {hex(int(dut.rear2.value))}"
    assert dut.rear3.value == 0x34, f"Max length test failed: expected 0x34 ('4'), got {hex(int(dut.rear3.value))}"
    print("Max length test passed")
    
    print("
=== Summary: 5/5 tests passed ===")