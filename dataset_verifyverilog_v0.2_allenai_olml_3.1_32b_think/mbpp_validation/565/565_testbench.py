import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_string_split(dut):
    """Test string splitting functionality"""
    
    # Test 1: split('python') - 6 characters
    # 'python' = 0x707974686f6e in hex, padded to 16 bytes
    dut.input_string.value = 0x707974686f6e00000000000000000000
    await Timer(10, units='ns')
    
    expected = [ord('p'), ord('y'), ord('t'), ord('h'), ord('o'), ord('n'), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    for i in range(16):
        actual = dut.characters[i].value
        if actual != expected[i]:
            raise TestFailure(f"Test 1 failed at position {i}: expected {expected[i]}, got {actual}")
    
    print("Test 1 passed: split('python')")
    
    # Test 2: split('Name') - 4 characters
    dut.input_string.value = 0x4e616d65000000000000000000000000
    await Timer(10, units='ns')
    
    expected = [ord('N'), ord('a'), ord('m'), ord('e'), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    for i in range(16):
        actual = dut.characters[i].value
        if actual != expected[i]:
            raise TestFailure(f"Test 2 failed at position {i}: expected {expected[i]}, got {actual}")
    
    print("Test 2 passed: split('Name')")
    
    # Test 3: split('program') - 7 characters
    dut.input_string.value = 0x70726f6772616d000000000000000000
    await Timer(10, units='ns')
    
    expected = [ord('p'), ord('r'), ord('o'), ord('g'), ord('r'), ord('a'), ord('m'), 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    for i in range(16):
        actual = dut.characters[i].value
        if actual != expected[i]:
            raise TestFailure(f"Test 3 failed at position {i}: expected {expected[i]}, got {actual}")
    
    print("Test 3 passed: split('program')")
    
    # Edge case 4: Empty string
    dut.input_string.value = 0
    await Timer(10, units='ns')
    
    for i in range(16):
        actual = dut.characters[i].value
        if actual != 0:
            raise TestFailure(f"Edge case failed: expected 0 at position {i}, got {actual}")
    
    print("Edge case 4 passed: empty string")
    
    # Edge case 5: Full 16 characters
    dut.input_string.value = 0x4142434445464748494a4b4c4d4e4f50  # "ABCDEFGHIJKLMNOP"
    await Timer(10, units='ns')
    
    expected = [ord('A'), ord('B'), ord('C'), ord('D'), ord('E'), ord('F'), ord('G'), ord('H'),
                ord('I'), ord('J'), ord('K'), ord('L'), ord('M'), ord('N'), ord('O'), ord('P')]
    
    for i in range(16):
        actual = dut.characters[i].value
        if actual != expected[i]:
            raise TestFailure(f"Edge case 5 failed at position {i}: expected {expected[i]}, got {actual}")
    
    print("Edge case 5 passed: 16-character string")
    print("
=== Summary: 5/5 tests passed ===")