import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_word_filter(dut):
    # Word encoding helper
    def encode_words(*words):
        result = 0
        for i, word in enumerate(words):
            padded = word.ljust(16)[:16].encode('ascii')
            for j, char in enumerate(padded):
                result |= (char << (i*128 + j*8))
        return result

    test_cases = [
        # Test 1: Original ['python','programming','language']
        {
            "n": 3,
            "words": encode_words("python", "is", "a", "programming", "language", "", "", ""),
            "expected": 0b10011000  # Positions 7,4,3 have long words
        },
        # Test 2: Original ['writing','program']
        {
            "n": 2,
            "words": encode_words("writing", "a", "program", "", "", "", "", ""),
            "expected": 0b10100000  # Positions 7,5
        },
        # Test 3: Original ['sorting']
        {
            "n": 5,
            "words": encode_words("sorting", "list", "", "", "", "", "", ""),
            "expected": 0b10000000  # Position 7 only
        },
        # Additional edge cases
        {
            "n": 0,
            "words": encode_words("a", "", "", "", "", "", "", ""),
            "expected": 0b10000000  # All words >0
        },
        {
            "n": 15,
            "words": encode_words("maximum_length_", "exactly_16_chars", "", "", "", "", "", ""),
            "expected": 0b11000000  # 14 chars and 16 chars (both >15?)
        }
    ]

    passed = 0
    for case in test_cases:
        dut.n.value = case["n"]
        dut.word_string.value = case["words"]
        await Timer(1, units='ns')
        if dut.word_mask.value == case["expected"]:
            passed += 1
            dut._log.info(f"PASS: n={case['n']} mask={bin(dut.word_mask.value)}")
        else:
            dut._log.error(f"FAIL: n={case['n']} got {bin(dut.word_mask.value)} expected {bin(case['expected'])}")
    
    total = len(test_cases)
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed} tests"