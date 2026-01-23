import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_decimal_to_binary(dut):
    """Test decimal to binary conversion with db prefix/suffix"""
    
    # Helper function to convert decimal to expected 72-bit binary string format
    def expected_output(decimal):
        # Convert to 7-bit binary string
        binary_7bit = format(decimal, '07b')
        # Build full string: 'db' + binary + 'db'
        full_str = 'db' + binary_7bit + 'db'
        # Convert to 72-bit value (9 chars * 8 bits)
        result = 0
        for i, char in enumerate(full_str):
            result |= (ord(char) << ((8 - 1 - i) * 8))
        return result
    
    # Test case 1: 0 -> "db0000000db"
    dut.decimal.value = 0
    await Timer(1, units='ns')
    expected = expected_output(0)
    actual = dut.binary_str.value.integer
    assert actual == expected, f"Test 0 failed: expected {expected:018x}, got {actual:018x}"
    print(f"Test 0 passed: decimal=0 -> {actual:018x}")
    
    # Test case 2: 15 -> "db0001111db"
    dut.decimal.value = 15
    await Timer(1, units='ns')
    expected = expected_output(15)
    actual = dut.binary_str.value.integer
    assert actual == expected, f"Test 15 failed: expected {expected:018x}, got {actual:018x}"
    print(f"Test 15 passed: decimal=15 -> {actual:018x}")
    
    # Test case 3: 32 -> "db0100000db"
    dut.decimal.value = 32
    await Timer(1, units='ns')
    expected = expected_output(32)
    actual = dut.binary_str.value.integer
    assert actual == expected, f"Test 32 failed: expected {expected:018x}, got {actual:018x}"
    print(f"Test 32 passed: decimal=32 -> {actual:018x}")
    
    # Test case 4: 103 -> "db1100111db"
    dut.decimal.value = 103
    await Timer(1, units='ns')
    expected = expected_output(103)
    actual = dut.binary_str.value.integer
    assert actual == expected, f"Test 103 failed: expected {expected:018x}, got {actual:018x}"
    print(f"Test 103 passed: decimal=103 -> {actual:018x}")
    
    # Test case 5: 255 (max 8-bit) -> "db1111111db"
    dut.decimal.value = 255
    await Timer(1, units='ns')
    expected = expected_output(255)
    actual = dut.binary_str.value.integer
    assert actual == expected, f"Test 255 failed: expected {expected:018x}, got {actual:018x}"
    print(f"Test 255 passed: decimal=255 -> {actual:018x}")
    
    # Test case 6: 1 -> "db0000001db"
    dut.decimal.value = 1
    await Timer(1, units='ns')
    expected = expected_output(1)
    actual = dut.binary_str.value.integer
    assert actual == expected, f"Test 1 failed: expected {expected:018x}, got {actual:018x}"
    print(f"Test 1 passed: decimal=1 -> {actual:018x}")
    
    print("All tests passed!")