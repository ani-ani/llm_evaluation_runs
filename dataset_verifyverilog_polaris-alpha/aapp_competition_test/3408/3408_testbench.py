import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_wildcard(dut):
    test_cases = [
        # Format: (words, pattern, expected)
        # Test 1: Pattern "a*a" encoded as [a=0, *=26, a=0]
        ([[0,0,0,0], [0,0,1,0], [0,1,0,0], [0,0,0,1]], [0,26,0,0], 2),
        # Test 2: Pattern "aaa*" encoded as [a=0, a=0, a=0, *=26]
        ([[0,0,0,0], [0,0,0,1], [0,0,0,2], [0,0,1,0]], [0,0,0,26], 1),
        # Test 3: Pattern "*aaa" encoded as [*=26, a=0, a=0, a=0]
        ([[0,0,0,0], [1,0,0,0], [0,0,0,0], [2,0,0,0]], [26,0,0,0], 3),
        # Edge case: No matches
        ([[1,1,1,1], [2,2,2,2], [3,3,3,3], [4,4,4,4]], [0,0,0,0], 0)
    ]
    passed = 0
    for words, pattern, expected in test_cases:
        dut.word0.value = LogicArray(words[0]).integer
        dut.word1.value = LogicArray(words[1]).integer
        dut.word2.value = LogicArray(words[2]).integer
        dut.word3.value = LogicArray(words[3]).integer
        dut.pattern.value = LogicArray(pattern).integer
        await Timer(1, units='ns')
        result = dut.match_count.value.integer
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Pattern {pattern} matched {result} words (expected {expected})")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
"