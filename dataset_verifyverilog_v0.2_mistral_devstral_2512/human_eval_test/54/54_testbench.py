import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_same_chars(dut):
    """Test same_chars module with various test cases"""
    
    # Test case 1: same chars, different order (1)
    # eabcdzzzz vs dddzzzzzzzddeddabc - both have: 1a, 1b, 1c, 1d, 1e, 6z (but first string has only 9 chars?)
    # Actually: eabcdzzzz = 9 chars, dddzzzzzzzddeddabc = 18 chars - let's use 8 char limit
    # Adapted: 'abcd    ' vs 'ddddabc ' (8 chars each)
    dut.s0.value = 0x6162636420202020  # "abcd    "
    dut.s1.value = 0x6464646462636120  # "ddddabc "
    await Timer(1, units='ns')
    assert dut.result.value == 0, "Test 1 failed: abcd vs ddd dabc should be different
"
    
    # Test case 2: identical strings
    # "abcd" vs "abcd"
    dut.s0.value = 0x6162636420202020  # "abcd    "
    dut.s1.value = 0x6162636420202020  # "abcd    "
    await Timer(1, units='ns')
    assert dut.result.value == 1, "Test 2 failed: abcd vs abcd should be same
"
    
    # Test case 3: same chars different order
    # "abcd    " vs "dcba    "
    dut.s0.value = 0x6162636420202020  # "abcd    "
    dut.s1.value = 0x6463626120202020  # "dcba    "
    await Timer(1, units='ns')
    assert dut.result.value == 1, "Test 3 failed: abcd vs dcba should be same
"
    
    # Test case 4: different character counts
    # "aabbc   " vs "accc    "
    dut.s0.value = 0x6161626263202020  # "aabbc   "
    dut.s1.value = 0x6163636320202020  # "accc    "
    await Timer(1, units='ns')
    assert dut.result.value == 0, "Test 4 failed: aabbc vs accc should be different
"
    
    # Test case 5: all same character
    # "aaaa    " vs "aaaa    "
    dut.s0.value = 0x6161616120202020  # "aaaa    "
    dut.s1.value = 0x6161616120202020  # "aaaa    "
    await Timer(1, units='ns')
    assert dut.result.value == 1, "Test 5 failed: aaaa vs aaaa should be same
"
    
    # Test case 6: extra character in second string
    # "abcd    " vs "abcdx   "
    dut.s0.value = 0x6162636420202020  # "abcd    "
    dut.s1.value = 0x6162636478202020  # "abcdx   "
    await Timer(1, units='ns')
    assert dut.result.value == 0, "Test 6 failed: abcd vs abcdx should be different
"
    
    # Test case 7: empty (all spaces) vs all spaces
    dut.s0.value = 0x2020202020202020  # "        "
    dut.s1.value = 0x2020202020202020  # "        "
    await Timer(1, units='ns')
    assert dut.result.value == 1, "Test 7 failed: spaces vs spaces should be same
"
    
    # Test case 8: different length characters (even though both 8 bytes)
    # "a       " vs "b       "
    dut.s0.value = 0x6120202020202020  # "a       "
    dut.s1.value = 0x6220202020202020  # "b       "
    await Timer(1, units='ns')
    assert dut.result.value == 0, "Test 8 failed: a vs b should be different
"
    
    # Test case 9: multiple repetitions
    # "aaabbbcc" vs "cccbbaaa"
    dut.s0.value = 0x6161616262626363  # "aaabbbcc"
    dut.s1.value = 0x6363636262626161  # "cccbbaaa"
    await Timer(1, units='ns')
    assert dut.result.value == 1, "Test 9 failed: aaabbbcc vs cccbbbaa should be same
"
    
    # Test case 10: original test adaptation - 'abcd' vs 'dddddddabc' (but limited to 8 chars)
    # "abcd    " vs "ddddabc "
    dut.s0.value = 0x6162636420202020  # "abcd    "
    dut.s1.value = 0x6464646462636120  # "ddddabc "
    await Timer(1, units='ns')
    assert dut.result.value == 0, "Test 10 failed: abcd vs ddd dabc should be different
"
    
    passed = 10
    total = 10
    print(f"
{passed}/{total} tests passed")
