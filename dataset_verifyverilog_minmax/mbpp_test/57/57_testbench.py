import cocotb
from cocotb.triggers import Timer
from math import pow

@cocotb.test()
async def test_max_num(dut):
    # Test cases: (input_list, expected_output)
    test_cases = [([1,2,3,0], 3210),
                  ([4,5,6,1], 6541),
                  ([1,2,3,9], 9321),
                  ([0,0,1,0], 1000),
                  ([9,9,9,9], 9999)]
    passed = 0
    
    for digits, expected in test_cases:
        for i in range(4):
            dut.digits[i].value = digits[i]
        await Timer(1, units='ns')
        result = dut.max_num.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {digits} → {result}")
        else:
            dut._log.error(f"FAIL: {digits} got {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")