import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_companies(dut):
    test_cases = [
        # Test 1: Original scaled N=8, K=4, C=3
        {'k': 4, 'c': 3, 'sectors': [1,1,9,9,1,6,6,39], 'expected': 2},
        # Test 2: Original scaled N=8 (last 2 sectors removed), K=2, C=2
        {'k': 2, 'c': 2, 'sectors': [1,1,1,1,1,2,2,2], 'expected': 2},
        # Test 3: Original scaled N=8, K=4, C=3
        {'k': 4, 'c': 3, 'sectors': [1,1,9,9,1,9,9,9], 'expected': 0}
    ]
    passed = 0
    for case in test_cases:
        dut.k.value = case['k']
        dut.c.value = case['c']
        for i in range(8):
            dut.sectors[i].value = case['sectors'][i]
        await Timer(1, units='ns')
        result = int(dut.company_count.value)
        if result == case['expected']:
            passed += 1
        else:
            dut._log.error(f"Test failed: Got {result}, expected {case['expected']} for {case}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")