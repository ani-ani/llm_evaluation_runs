import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_string_to_tuple(dut):
    """Test string to tuple conversion with whitespace removal"""
    
    # Test 1: "python 3.0" (8 chars: 'p','y','t','h','o','n',' ','3') then '0' would be char_7
    # Wait, we only have 8 characters total. Let's map properly.
    # "python 3.0" has 10 chars. We'll use first 8: 'p','y','t','h','o','n',' ','3'
    # And add '0' as char_7... but that's 9. Let's use 8 char limit.
    # Actually let's adapt: "python 3" (8 chars) or pad with spaces
    
    dut._log.info("Running test cases for string_to_tuple")
    
    # Test case 1: "py th on" (8 chars with spaces) -> should produce 'p','y','t','h','o','n'
    # Input: p, y, space, t, h, space, o, n
    chars = [ord('p'), ord('y'), 0x20, ord('t'), ord('h'), 0x20, ord('o'), ord('n')]
    for i in range(8):
        setattr(dut, f'char_{i}', chars[i])
    
    await Timer(1, units='ns')  # Combinational logic settles
    
    expected = [ord('p'), ord('y'), ord('t'), ord('h'), ord('o'), ord('n'), 0, 0]
    expected_count = 6
    
    for i in range(8):
        actual = getattr(dut, f'result_{i}').value
        if actual != expected[i]:
            raise TestFailure(f"Test 1 result_{i}: expected {expected[i]}, got {actual}")
    
    assert dut.count.value == expected_count, f"Test 1 count: expected {expected_count}, got {dut.count.value}"
    dut._log.info("Test 1 passed: 'py th on' -> ('p','y','t','h','o','n')")
    
    # Test case 2: "item1   " (8 chars) -> ('i','t','e','m','1')
    # i, t, e, m, 1, space, space, space
    chars = [ord('i'), ord('t'), ord('e'), ord('m'), ord('1'), 0x20, 0x20, 0x20]
    for i in range(8):
        setattr(dut, f'char_{i}', chars[i])
    
    await Timer(1, units='ns')
    
    expected = [ord('i'), ord('t'), ord('e'), ord('m'), ord('1'), 0, 0, 0]
    expected_count = 5
    
    for i in range(8):
        actual = getattr(dut, f'result_{i}').value
        if actual != expected[i]:
            raise TestFailure(f"Test 2 result_{i}: expected {expected[i]}, got {actual}")
    
    assert dut.count.value == expected_count, f"Test 2 count: expected {expected_count}, got {dut.count.value}"
    dut._log.info("Test 2 passed: 'item1   ' -> ('i','t','e','m','1')")
    
    # Test case 3: "15.10   " (8 chars) -> ('1','5','.','1','0')
    chars = [ord('1'), ord('5'), ord('.'), ord('1'), ord('0'), 0x20, 0x20, 0x20]
    for i in range(8):
        setattr(dut, f'char_{i}', chars[i])
    
    await Timer(1, units='ns')
    
    expected = [ord('1'), ord('5'), ord('.'), ord('1'), ord('0'), 0, 0, 0]
    expected_count = 5
    
    for i in range(8):
        actual = getattr(dut, f'result_{i}').value
        if actual != expected[i]:
            raise TestFailure(f"Test 3 result_{i}: expected {expected[i]}, got {actual}")
    
    assert dut.count.value == expected_count, f"Test 3 count: expected {expected_count}, got {dut.count.value}"
    dut._log.info("Test 3 passed: '15.10   ' -> ('1','5','.','1','0')")
    
    # Test 4: All spaces
    chars = [0x20] * 8
    for i in range(8):
        setattr(dut, f'char_{i}', chars[i])
    
    await Timer(1, units='ns')
    
    for i in range(8):
        actual = getattr(dut, f'result_{i}').value
        if actual != 0:
            raise TestFailure(f"Test 4 result_{i}: expected 0, got {actual}")
    
    assert dut.count.value == 0, f"Test 4 count: expected 0, got {dut.count.value}"
    dut._log.info("Test 4 passed: All spaces -> empty tuple")
    
    # Test 5: No spaces
    chars = [ord('a'), ord('b'), ord('c'), ord('d'), ord('e'), ord('f'), ord('g'), ord('h')]
    for i in range(8):
        setattr(dut, f'char_{i}', chars[i])
    
    await Timer(1, units='ns')
    
    expected = chars + [0, 0]  # Already 8 chars, but we need 8 outputs - wait, if all non-space, count=8
    # With 8 inputs, all non-space, we fill all 8 result ports
    # But we defined only 8 result ports, so count=8 means result_7 = 'h'
    
    for i in range(8):
        actual = getattr(dut, f'result_{i}').value
        if actual != chars[i]:
            raise TestFailure(f"Test 5 result_{i}: expected {chars[i]}, got {actual}")
    
    assert dut.count.value == 8, f"Test 5 count: expected 8, got {dut.count.value}"
    dut._log.info("Test 5 passed: 'abcdefgh' -> ('a','b','c','d','e','f','g','h')")
    
    dut._log.info("All 5/5 tests passed!")
