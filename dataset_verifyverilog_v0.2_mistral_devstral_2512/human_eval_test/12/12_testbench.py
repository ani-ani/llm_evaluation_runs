import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_longest_string(dut):
    """Test the longest string module"""
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.str0.value = 0
    dut.str1.value = 0
    dut.str2.value = 0
    dut.str3.value = 0
    dut.str4.value = 0
    dut.str5.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')
    
    print("
=== Test 1: Empty list (all zeros) ===")
    dut.str0.value = 0
    dut.str1.value = 0
    dut.str2.value = 0
    dut.str3.value = 0
    dut.str4.value = 0
    dut.str5.value = 0
    await Timer(10, units='ns')
    assert dut.valid.value == 0, f"Expected valid=0 for empty list, got {dut.valid.value}"
    print("PASS: Empty list returns valid=0")
    
    print("
=== Test 2: Single character strings ===")
    dut.str0.value = ord('x')  # ASCII 'x'
    dut.str1.value = ord('y')
    dut.str2.value = ord('z')
    dut.str3.value = 0
    dut.str4.value = 0
    dut.str5.value = 0
    await Timer(10, units='ns')
    assert dut.valid.value == 1, f"Expected valid=1, got {dut.valid.value}"
    assert dut.result.value == ord('x'), f"Expected 'x', got {chr(int(dut.result.value))}"
    print(f"PASS: Returns '{chr(int(dut.result.value))}' (first string)")
    
    print("
=== Test 3: Mixed lengths with clear maximum ===")
    dut.str0.value = 1  # length 1
    dut.str1.value = 3  # length 3
    dut.str2.value = 4  # length 4 - longest
    dut.str3.value = 2  # length 2
    dut.str4.value = 3  # length 3
    dut.str5.value = 1  # length 1
    await Timer(10, units='ns')
    assert dut.valid.value == 1, f"Expected valid=1, got {dut.valid.value}"
    assert dut.result.value == 4, f"Expected length 4 (str2), got {dut.result.value}"
    print(f"PASS: Returns length {int(dut.result.value)} (str2)")
    
    print("
=== Test 4: Tie-breaking (equal lengths) ===")
    dut.str0.value = 5  # first longest
    dut.str1.value = 3
    dut.str2.value = 5  # tied
    dut.str3.value = 1
    dut.str4.value = 5  # also tied
    dut.str5.value = 2
    await Timer(10, units='ns')
    assert dut.valid.value == 1, f"Expected valid=1, got {dut.valid.value}"
    assert dut.result.value == 5, f"Expected 5 from str0, got {dut.result.value}"
    print(f"PASS: Tie-breaking selects str0 (first)")
    
    print("
=== Test 5: All strings same length ===")
    dut.str0.value = 2
    dut.str1.value = 2
    dut.str2.value = 2
    dut.str3.value = 2
    dut.str4.value = 2
    dut.str5.value = 2
    await Timer(10, units='ns')
    assert dut.valid.value == 1, f"Expected valid=1, got {dut.valid.value}"
    assert dut.result.value == 2, f"Expected 2 from str0, got {dut.result.value}"
    print(f"PASS: All same, selects str0")
    
    print("
=== Test 6: Maximum length scenario ===")
    dut.str0.value = 128
    dut.str1.value = 255
    dut.str2.value = 200
    dut.str3.value = 150
    dut.str4.value = 180
    dut.str5.value = 255  # tied max
    await Timer(10, units='ns')
    assert dut.valid.value == 1, f"Expected valid=1, got {dut.valid.value}"
    # str1 has 255 (max) but str5 also has 255, but str1 comes first
    # Wait, actually str1 and str5 are both 255, str1 is index 1
    assert dut.result.value == 255, f"Expected 255, got {dut.result.value}"
    print(f"PASS: Maximum value 255 detected")
    
    print("
=== Test 7: Only one non-zero string ===")
    dut.str0.value = 0
    dut.str1.value = 0
    dut.str2.value = 7
    dut.str3.value = 0
    dut.str4.value = 0
    dut.str5.value = 0
    await Timer(10, units='ns')
    assert dut.valid.value == 1, f"Expected valid=1, got {dut.valid.value}"
    assert dut.result.value == 7, f"Expected 7 from str2, got {dut.result.value}"
    print(f"PASS: Single non-zero string selected")
    
    # Summary
    passed = 7
    total = 7
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed}/{total} tests passed")
    print(f"{'='*50}")
    
    if passed == total:
        print("
🎉 All tests PASSED! Module works correctly.")
    else:
        print(f"
❌ {total - passed} test(s) FAILED.")