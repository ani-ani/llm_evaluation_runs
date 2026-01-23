import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_all_characters_same(dut):
    """Test all_characters_same module"""
    
    # Initialize inputs
    dut.char_0.value = 0
    dut.char_1.value = 0
    dut.char_2.value = 0
    dut.char_3.value = 0
    dut.char_4.value = 0
    dut.char_5.value = 0
    dut.char_6.value = 0
    dut.char_7.value = 0
    dut.valid_length.value = 0
    
    await Timer(10, units='ns')
    
    # Test 1: "python" -> p,y,t,h,o,n (all different) -> Should be False (0)
    # Encoding: 'p'=0x70, 'y'=0x79, 't'=0x74, 'h'=0x68, 'o'=0x6F, 'n'=0x6E
    dut.char_0.value = 0x70  # 'p'
    dut.char_1.value = 0x79  # 'y'
    dut.char_2.value = 0x74  # 't'
    dut.char_3.value = 0x68  # 'h'
    dut.char_4.value = 0x6F  # 'o'
    dut.char_5.value = 0x6E  # 'n'
    dut.char_6.value = 0x00  # unused
    dut.char_7.value = 0x00  # unused
    dut.valid_length.value = 6  # 6 characters
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 1 failed: 'python' should return False, got {dut.result.value}"
    print("Test 1 passed: 'python' correctly returned False")
    
    # Test 2: "aaa" -> all 'a' (0x61) -> Should be True (1)
    dut.char_0.value = 0x61  # 'a'
    dut.char_1.value = 0x61  # 'a'
    dut.char_2.value = 0x61  # 'a'
    dut.char_3.value = 0x00
    dut.char_4.value = 0x00
    dut.char_5.value = 0x00
    dut.char_6.value = 0x00
    dut.char_7.value = 0x00
    dut.valid_length.value = 3  # 3 characters
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 2 failed: 'aaa' should return True, got {dut.result.value}"
    print("Test 2 passed: 'aaa' correctly returned True")
    
    # Test 3: "data" -> d,a,t,a -> Should be False (0)
    dut.char_0.value = 0x64  # 'd'
    dut.char_1.value = 0x61  # 'a'
    dut.char_2.value = 0x74  # 't'
    dut.char_3.value = 0x61  # 'a'
    dut.char_4.value = 0x00
    dut.char_5.value = 0x00
    dut.char_6.value = 0x00
    dut.char_7.value = 0x00
    dut.valid_length.value = 4  # 4 characters
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 3 failed: 'data' should return False, got {dut.result.value}"
    print("Test 3 passed: 'data' correctly returned False")
    
    # Test 4: Single character 'a' -> Should be True (1)
    dut.char_0.value = 0x61
    dut.char_1.value = 0x00
    dut.char_2.value = 0x00
    dut.char_3.value = 0x00
    dut.char_4.value = 0x00
    dut.char_5.value = 0x00
    dut.char_6.value = 0x00
    dut.char_7.value = 0x00
    dut.valid_length.value = 1  # 1 character
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 4 failed: single char should return True, got {dut.result.value}"
    print("Test 4 passed: single character correctly returned True")
    
    # Test 5: "zzzzzzzz" (8 characters) all same -> Should be True (1)
    dut.char_0.value = 0x7A  # 'z'
    dut.char_1.value = 0x7A
    dut.char_2.value = 0x7A
    dut.char_3.value = 0x7A
    dut.char_4.value = 0x7A
    dut.char_5.value = 0x7A
    dut.char_6.value = 0x7A
    dut.char_7.value = 0x7A
    dut.valid_length.value = 8  # 8 characters
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 5 failed: 'zzzzzzzz' should return True, got {dut.result.value}"
    print("Test 5 passed: 'zzzzzzzz' correctly returned True")
    
    # Test 6: "zzzzzxy" -> Should be False (0)
    dut.char_0.value = 0x7A  # 'z'
    dut.char_1.value = 0x7A
    dut.char_2.value = 0x7A
    dut.char_3.value = 0x7A
    dut.char_4.value = 0x7A
    dut.char_5.value = 0x78  # 'x'
    dut.char_6.value = 0x79  # 'y'
    dut.char_7.value = 0x00
    dut.valid_length.value = 7  # 7 characters
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 6 failed: 'zzzzzxy' should return False, got {dut.result.value}"
    print("Test 6 passed: 'zzzzzxy' correctly returned False")
    
    print(f"
Summary: All 6 tests passed!")