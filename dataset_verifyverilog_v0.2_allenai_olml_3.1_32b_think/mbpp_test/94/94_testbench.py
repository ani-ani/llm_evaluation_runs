import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def str_to_ascii(name):
    """Convert 4-char string to 32-bit hex"""
    if len(name) < 4:
        name = name.ljust(4)
    return int.from_bytes(name[:4].encode('ascii'), 'big')

@cocotb.test()
async def test_find_min_tuple(dut):
    """Test finding tuple with minimum second value"""
    
    # Test case 1: Rash(143), Manj(200), Vars(100)
    dut.values[0] = 143
    dut.values[1] = 200
    dut.values[2] = 100
    dut.values[3] = 255  # Unused - max value
    dut.values[4] = 255
    dut.values[5] = 255
    dut.values[6] = 255
    dut.values[7] = 255
    
    dut.names[0] = str_to_ascii('Rash')
    dut.names[1] = str_to_ascii('Manj')
    dut.names[2] = str_to_ascii('Vars')
    dut.names[3] = 0x20202020
    dut.names[4] = 0x20202020
    dut.names[5] = 0x20202020
    dut.names[6] = 0x20202020
    dut.names[7] = 0x20202020
    
    await Timer(10, units='ns')
    
    expected = str_to_ascii('Vars')
    actual = int(dut.result_name.value)
    
    if actual != expected:
        raise TestFailure(f"Test 1 failed: expected 0x{expected:08X}, got 0x{actual:08X}")
    print(f"Test 1 passed: Got correct name 'Vars'")
    
    # Test case 2: Yash(185), Dawo(125), Sany(175)
    dut.values[0] = 185
    dut.values[1] = 125
    dut.values[2] = 175
    
    dut.names[0] = str_to_ascii('Yash')
    dut.names[1] = str_to_ascii('Dawo')
    dut.names[2] = str_to_ascii('Sany')
    
    await Timer(10, units='ns')
    
    expected = str_to_ascii('Dawo')
    actual = int(dut.result_name.value)
    
    if actual != expected:
        raise TestFailure(f"Test 2 failed: expected 0x{expected:08X}, got 0x{actual:08X}")
    print(f"Test 2 passed: Got correct name 'Dawo'")
    
    # Test case 3: Sai(345), Sal(145), Ayes(96)
    dut.values[0] = 255  # Saturate to 8-bit
    dut.values[1] = 145
    dut.values[2] = 96
    
    dut.names[0] = str_to_ascii('Sai ')
    dut.names[1] = str_to_ascii('Sal ')
    dut.names[2] = str_to_ascii('Ayes')
    
    await Timer(10, units='ns')
    
    expected = str_to_ascii('Ayes')
    actual = int(dut.result_name.value)
    
    if actual != expected:
        raise TestFailure(f"Test 3 failed: expected 0x{expected:08X}, got 0x{actual:08X}")
    print(f"Test 3 passed: Got correct name 'Ayes'")
    
    # Additional edge case: tiebreaker (lower index should win)
    dut.values[0] = 100
    dut.values[1] = 100
    dut.names[0] = str_to_ascii('First')
    dut.names[1] = str_to_ascii('Secnd')
    
    await Timer(10, units='ns')
    
    expected = str_to_ascii('First')
    actual = int(dut.result_name.value)
    
    if actual != expected:
        raise TestFailure(f"Tiebreaker test failed: expected 0x{expected:08X}, got 0x{actual:08X}")
    print(f"Tiebreaker test passed: Lower index wins on ties")
    
    print(f"
=== Summary: All 4 tests passed ===")