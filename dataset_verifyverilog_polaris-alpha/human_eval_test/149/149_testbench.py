import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestSuccess

@cocotb.test()
async def test_string_filter_sort(dut):
    # Helper to convert strings to packed ASCII
    def str_to_bits(s, length=8):
        padded = s.ljust(length)[:length]
        return [ord(c) for c in padded]
    
    # Adapted test cases (words padded to 8 chars)
    test_cases = [
        (["aa", "a", "aaa"], 2, [["aa"] + [""]*7]),
        (["school", "AI", "asdf", "b"], 2, [["AI", "asdf", "school"] + [""]*5]),
        (["d", "dcba", "abcd", "a"], 4, [["abcd", "dcba"] + [""]*6]),
        (["aaaa", "bbbb", "dd", "cc"], 2, [["aaaa", "bbbb", "cc", "dd"] + [""]*4]),
        (["AI", "ai", "au"], 2, [["AI", "ai", "au"] + [""]*5])
    ]
    
    passed = 0
    for inputs, in_len, expected_outputs in test_cases:
        # Convert inputs to 8-byte ASCII arrays
        input_words = [str_to_bits(w, 8) for w in inputs]
        expected = [str_to_bits(w, 8) for w in expected_outputs[0]]
        
        # Pad input to 8 words
        while len(input_words) < 8:
            input_words.append([0]*8)
        
        # Set DUT inputs
        for i in range(8):
            dut.words[i].value = int.from_bytes(bytes(input_words[i]), 'big')
        dut.word_length.value = in_len
        
        await Timer(10, units='ns')
        
        # Collect output
        valid_count = int(dut.valid_count.value)
        actual_words = []
        for i in range(valid_count):
            word_val = dut.sorted[i].value.integer
            chars = [chr((word_val >> (8*(7-j))) & 0xff) for j in range(8)]
            actual_words.append(''.join(chars).rstrip())
        
        expected_cleaned = [w.rstrip() for w in expected_outputs[0] if w.strip()]
        
        if valid_count == len(expected_cleaned) and actual_words == expected_cleaned:
            passed += 1
            dut._log.info(f"PASS: {inputs} -> {actual_words}")
        else:
            dut._log.error(f"FAIL: {inputs}
  Expected: {expected_cleaned}
  Got: {actual_words} (count={valid_count})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed < len(test_cases):
        raise TestFailure("Some tests failed")
    else:
        raise TestSuccess("All tests passed")