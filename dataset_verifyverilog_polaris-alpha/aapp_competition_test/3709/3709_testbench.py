import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_interesting(dut):
    test_cases = [
        {
            "valid": 0b0000000000011111,
            "problems": [5, 6, 4, 4, 4] + [0]*11,
            "expected": 0
        },
        {
            "valid": 0b0000000000000111,
            "problems": [2, 3, 1] + [0]*13,
            "expected": 1
        },
        {
            "valid": 0b1000000000000011,
            "problems": [0, 15, 0] + [0]*13,
            "expected": 1
        },
        {
            "valid": 0b0000000000000011,
            "problems": [3, 3] + [0]*14,
            "expected": 0
        },
        {
            "valid": 0b0000000000000001,
            "problems": [0] + [0]*15,
            "expected": 1
        }
    ]
    passed = 0
    for case in test_cases:
        dut.valid.value = case["valid"]
        flat = 0
        for i, p in enumerate(case["problems"]):
            flat |= p << (i*4)
        dut.problems.value = flat
        await Timer(1, units='ns')
        if dut.result.value == case["expected"]:
            passed += 1
        else:
            dut._log.error(f"Case failed: Valid=0b{case['valid']:016b}, Expected={case['expected']}, Got={dut.result.value}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")