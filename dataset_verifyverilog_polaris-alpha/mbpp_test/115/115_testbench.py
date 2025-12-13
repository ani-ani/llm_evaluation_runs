import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_check_empty_dicts(dut):
    test_cases = [
        # Test 1: [{},{},{}] -> All empty
        (0b0000, 1),
        # Test 2: [{1:2},{},{}] -> First non-empty
        (0b1000, 0),
        # Test 3: [{}] (padded with zeros for 4-element input)
        (0b0000, 1)
    ]
    passed = 0
    for idx, (input_val, expected) in enumerate(test_cases):
        dut.dict_list.value = input_val
        await Timer(1, units='ns')
        result = dut.all_empty.value
        if result == expected:
            passed += 1
            dut._log.info(f"Test {idx+1} PASSED")
        else:
            dut._log.error(f"Test {idx+1} FAILED: Input {bin(input_val)} -> {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")