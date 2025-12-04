import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_duplicate(dut):
    # Original test cases scaled to 8-element arrays
    test_cases = [
        ([1,2,3,4,5,0,0,0], False),  # Test 1 extended with zero padding
        ([1,2,3,4,4,0,0,0], True),   # Test 2 with obvious duplicate
        ([1,1,2,2,3,3,4,4], True),   # Test 3 truncated to 8 elements
        ([8'h00, 8'hFF, 8'h55, 8'h55, 0,0,0,0], True),  # Edge case with different bit patterns
        ([128, 128, 128, 128, 128, 128, 128, 128], True)  # Max duplicate case
    ]
    passed = 0
    for idx, (arr, expected) in enumerate(test_cases):
        for i in range(8):
            dut.array[i].value = arr[i]
        await Timer(1, units='ns')
        result = dut.has_duplicate.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS {idx}: {arr} => {result}")
        else:
            dut._log.error(f"FAIL {idx}: {arr} => {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), f"{passed} passed but expected all {len(test_cases)} tests to pass"