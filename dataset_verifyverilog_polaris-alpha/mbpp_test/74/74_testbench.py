import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_pattern_matcher(dut):
    # Test cases: (length, colors, patterns, expected)
    # IDs mapped: red=2, green=3, greenn=4, a=0, b=1
    test_cases = [
        (3, [2,3,3,0,0,0,0,0], [0,1,1,0,0,0,0,0], True),  # Original Test1
        (3, [2,3,4,0,0,0,0,0], [0,1,1,0,0,0,0,0], False), # Modified Test2 (greenn→4)
        (3, [2,3,4,0,0,0,0,0], [0,1,0,0,0,0,0,0], False), # Length match but pattern≠color
        (2, [2,3,0,0,0,0,0,0], [0,1,0,0,0,0,0,0], False), # Original Test3 (length mismatch)
        (4, [5,5,5,5,0,0,0,0], [9,9,9,9,0,0,0,0], True),  # All identical
        (4, [1,2,3,4,0,0,0,0], [5,6,7,8,0,0,0,0], True)   # All different
    ]
    
    passed = 0
    for length, colors, patterns, expected in test_cases:
        dut.length.value = length
        for i in range(8):
            dut.colors[i].value = colors[i]
            dut.patterns[i].value = patterns[i]
        await Timer(1, 'ns')
        result = dut.match.value
        if bool(result) == expected:
            passed += 1
            dut._log.info(f"PASS: L={length} C={colors[:length]} P={patterns[:length]} => {result}")
        else:
            dut._log.error(f"FAIL: L={length} C={colors[:length]} P={patterns[:length]} => {result} (expected {expected})")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total