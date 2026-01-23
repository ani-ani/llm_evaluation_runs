import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_ascii_value(dut):
    """Test ASCII value conversion for various characters"""
    
    # Test case 1: 'A' (ASCII 65 = 0x41)
    dut.char_in.value = 0x41
    await Timer(10, units='ns')
    result = int(dut.ascii_out.value)
    print(f"Test 1: char_in = 0x41 ('A'), ascii_out = {result} (expected 65)")
    assert result == 65, f"Expected 65, got {result}"
    
    # Test case 2: 'R' (ASCII 82 = 0x52)
    dut.char_in.value = 0x52
    await Timer(10, units='ns')
    result = int(dut.ascii_out.value)
    print(f"Test 2: char_in = 0x52 ('R'), ascii_out = {result} (expected 82)")
    assert result == 82, f"Expected 82, got {result}"
    
    # Test case 3: 'S' (ASCII 83 = 0x53)
    dut.char_in.value = 0x53
    await Timer(10, units='ns')
    result = int(dut.ascii_out.value)
    print(f"Test 3: char_in = 0x53 ('S'), ascii_out = {result} (expected 83)")
    assert result == 83, f"Expected 83, got {result}"
    
    # Additional test case 4: 'a' (ASCII 97 = 0x61)
    dut.char_in.value = 0x61
    await Timer(10, units='ns')
    result = int(dut.ascii_out.value)
    print(f"Test 4: char_in = 0x61 ('a'), ascii_out = {result} (expected 97)")
    assert result == 97, f"Expected 97, got {result}"
    
    # Additional test case 5: '0' (ASCII 48 = 0x30)
    dut.char_in.value = 0x30
    await Timer(10, units='ns')
    result = int(dut.ascii_out.value)
    print(f"Test 5: char_in = 0x30 ('0'), ascii_out = {result} (expected 48)")
    assert result == 48, f"Expected 48, got {result}"
    
    # Additional test case 6: Space character (ASCII 32 = 0x20)
    dut.char_in.value = 0x20
    await Timer(10, units='ns')
    result = int(dut.ascii_out.value)
    print(f"Test 6: char_in = 0x20 (' '), ascii_out = {result} (expected 32)")
    assert result == 32, f"Expected 32, got {result}"
    
    # Additional test case 7: Null character (ASCII 0 = 0x00)
    dut.char_in.value = 0x00
    await Timer(10, units='ns')
    result = int(dut.ascii_out.value)
    print(f"Test 7: char_in = 0x00 (NUL), ascii_out = {result} (expected 0)")
    assert result == 0, f"Expected 0, got {result}"
    
    # Additional test case 8: DEL character (ASCII 127 = 0x7F)
    dut.char_in.value = 0x7F
    await Timer(10, units='ns')
    result = int(dut.ascii_out.value)
    print(f"Test 8: char_in = 0x7F (DEL), ascii_out = {result} (expected 127)")
    assert result == 127, f"Expected 127, got {result}"
    
    print("
All 8/8 tests passed!")