import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_remove_odd(dut):
    """Test remove_odd module with various strings"""
    
    # Test 1: "python" -> "yhn"
    # Positions: p(1), y(2), t(3), h(4), o(5), n(6), null(7), null(8)
    # Keep: y(2), h(4), n(6), null(8)
    dut.char_1.value = ord('p')
    dut.char_2.value = ord('y')
    dut.char_3.value = ord('t')
    dut.char_4.value = ord('h')
    dut.char_5.value = ord('o')
    dut.char_6.value = ord('n')
    dut.char_7.value = 0
    dut.char_8.value = 0
    await Timer(1, units='ns')
    
    result_1 = chr(int(dut.result_1.value))
    result_2 = chr(int(dut.result_2.value))
    result_3 = chr(int(dut.result_3.value))
    result_4 = chr(int(dut.result_4.value))
    
    assert result_1 == 'y', f"Test 1 failed: expected 'y', got '{result_1}'"
    assert result_2 == 'h', f"Test 1 failed: expected 'h', got '{result_2}'"
    assert result_3 == 'n', f"Test 1 failed: expected 'n', got '{result_3}'"
    assert result_4 == chr(0), f"Test 1 failed: expected null, got '{result_4}'"
    print("Test 1 passed: 'python' -> 'yhn'")
    
    # Test 2: "program" -> "rga"
    # Positions: p(1), r(2), o(3), g(4), r(5), a(6), m(7), null(8)
    # Keep: r(2), g(4), a(6), null(8)
    dut.char_1.value = ord('p')
    dut.char_2.value = ord('r')
    dut.char_3.value = ord('o')
    dut.char_4.value = ord('g')
    dut.char_5.value = ord('r')
    dut.char_6.value = ord('a')
    dut.char_7.value = ord('m')
    dut.char_8.value = 0
    await Timer(1, units='ns')
    
    result_1 = chr(int(dut.result_1.value))
    result_2 = chr(int(dut.result_2.value))
    result_3 = chr(int(dut.result_3.value))
    result_4 = chr(int(dut.result_4.value))
    
    assert result_1 == 'r', f"Test 2 failed: expected 'r', got '{result_1}'"
    assert result_2 == 'g', f"Test 2 failed: expected 'g', got '{result_2}'"
    assert result_3 == 'a', f"Test 2 failed: expected 'a', got '{result_3}'"
    assert result_4 == chr(0), f"Test 2 failed: expected null, got '{result_4}'"
    print("Test 2 passed: 'program' -> 'rga'")
    
    # Test 3: "language" -> "agae"
    # Positions: l(1), a(2), n(3), g(4), u(5), a(6), g(7), e(8)
    # Keep: a(2), g(4), a(6), e(8)
    dut.char_1.value = ord('l')
    dut.char_2.value = ord('a')
    dut.char_3.value = ord('n')
    dut.char_4.value = ord('g')
    dut.char_5.value = ord('u')
    dut.char_6.value = ord('a')
    dut.char_7.value = ord('g')
    dut.char_8.value = ord('e')
    await Timer(1, units='ns')
    
    result_1 = chr(int(dut.result_1.value))
    result_2 = chr(int(dut.result_2.value))
    result_3 = chr(int(dut.result_3.value))
    result_4 = chr(int(dut.result_4.value))
    
    assert result_1 == 'a', f"Test 3 failed: expected 'a', got '{result_1}'"
    assert result_2 == 'g', f"Test 3 failed: expected 'g', got '{result_2}'"
    assert result_3 == 'a', f"Test 3 failed: expected 'a', got '{result_3}'"
    assert result_4 == 'e', f"Test 3 failed: expected 'e', got '{result_4}'"
    print("Test 3 passed: 'language' -> 'agae'")
    
    # Test 4: All odd positions, even positions empty
    # Input: "a.b.c.d." (8 chars)
    # Keep: ., ., ., .
    dut.char_1.value = ord('a')
    dut.char_2.value = ord('.')
    dut.char_3.value = ord('b')
    dut.char_4.value = ord('.')
    dut.char_5.value = ord('c')
    dut.char_6.value = ord('.')
    dut.char_7.value = ord('d')
    dut.char_8.value = ord('.')
    await Timer(1, units='ns')
    
    assert chr(int(dut.result_1.value)) == '.'
    assert chr(int(dut.result_2.value)) == '.'
    assert chr(int(dut.result_3.value)) == '.'
    assert chr(int(dut.result_4.value)) == '.'
    print("Test 4 passed: odd-only positions correctly kept")
    
    # Test 5: Empty input (all nulls)
    dut.char_1.value = 0
    dut.char_2.value = 0
    dut.char_3.value = 0
    dut.char_4.value = 0
    dut.char_5.value = 0
    dut.char_6.value = 0
    dut.char_7.value = 0
    dut.char_8.value = 0
    await Timer(1, units='ns')
    
    assert int(dut.result_1.value) == 0
    assert int(dut.result_2.value) == 0
    assert int(dut.result_3.value) == 0
    assert int(dut.result_4.value) == 0
    print("Test 5 passed: empty input handled correctly")
    
    print("
All 5 tests passed!")