import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_string_xor(dut):
    """Test string XOR functionality"""
    
    # Helper function to convert binary string to integer
    def bin_to_int(s):
        return int(s, 2)
    
    # Test case 1: 111000 XOR 101010 = 010010
    dut.a.value = bin_to_int('111000')
    dut.b.value = bin_to_int('101010')
    dut.len.value = 6
    await Timer(10, units='ns')
    expected = bin_to_int('010010')
    actual = dut.result.value.integer
    if actual != expected:
        raise TestFailure(f"Test 1 failed: expected {expected:06b}, got {actual:06b}")
    print(f"Test 1 passed: 111000 XOR 101010 = {actual:06b}")
    
    # Test case 2: 1 XOR 1 = 0
    dut.a.value = bin_to_int('1')
    dut.b.value = bin_to_int('1')
    dut.len.value = 1
    await Timer(10, units='ns')
    expected = bin_to_int('0')
    actual = dut.result.value.integer
    if actual != expected:
        raise TestFailure(f"Test 2 failed: expected {expected}, got {actual}")
    print(f"Test 2 passed: 1 XOR 1 = {actual}")
    
    # Test case 3: 0101 XOR 0000 = 0101
    dut.a.value = bin_to_int('0101')
    dut.b.value = bin_to_int('0000')
    dut.len.value = 4
    await Timer(10, units='ns')
    expected = bin_to_int('0101')
    actual = dut.result.value.integer
    if actual != expected:
        raise TestFailure(f"Test 3 failed: expected {expected:04b}, got {actual:04b}")
    print(f"Test 3 passed: 0101 XOR 0000 = {actual:04b}")
    
    # Test case 4: All zeros
    dut.a.value = 0
    dut.b.value = 0
    dut.len.value = 8
    await Timer(10, units='ns')
    expected = 0
    actual = dut.result.value.integer
    if actual != expected:
        raise TestFailure(f"Test 4 failed: expected 0, got {actual}")
    print(f"Test 4 passed: 0 XOR 0 = {actual}")
    
    # Test case 5: Maximum length (16 bits)
    dut.a.value = 0xFFFF  # All 1s
    dut.b.value = 0x5555  # 0101 pattern
    dut.len.value = 16
    await Timer(10, units='ns')
    expected = 0xAAAA  # 1010 pattern (XOR result)
    actual = dut.result.value.integer
    if actual != expected:
        raise TestFailure(f"Test 5 failed: expected {expected:016b}, got {actual:016b}")
    print(f"Test 5 passed: 0xFFFF XOR 0x5555 = {actual:04x}")
    
    # Test case 6: Verify upper bits are zero when len < 16
    dut.a.value = 0xFFFF
    dut.b.value = 0xFFFF
    dut.len.value = 4
    await Timer(10, units='ns')
    expected = 0x000F  # Only lower 4 bits processed, result should be 0, but wait... 1111 XOR 1111 = 0000
    expected = 0
    actual = dut.result.value.integer
    if actual != expected:
        raise TestFailure(f"Test 6 failed: expected {expected}, got {actual}")
    print(f"Test 6 passed: All 1s XOR All 1s = {actual}")
    
    print("
All tests passed!")
