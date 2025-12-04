import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_dict_sum(dut):
    test_cases = [
        # Test case 1: Original Test 1 with 3 values (last=0)
        {'vals': (100, 200, 300, 0), 'expected': 600},
        # Test case 2: Original Test 2 with 3 values
        {'vals': (25, 18, 45, 0), 'expected': 88},
        # Test case 3: Original Test 3 with 3 values
        {'vals': (36, 39, 49, 0), 'expected': 124},
        # Edge case: All values = 0
        {'vals': (0, 0, 0, 0), 'expected': 0},
        # Full 4-value test
        {'vals': (100, 200, 300, 400), 'expected': 1000}
    ]
    
    passed = 0
    for case in test_cases:
        dut.val0.value = case['vals'][0]
        dut.val1.value = case['vals'][1]
        dut.val2.value = case['vals'][2]
        dut.val3.value = case['vals'][3]
        await Timer(1, units='ns')
        
        result = dut.sum_total.value.integer
        if result == case['expected']:
            passed += 1
            dut._log.info(f"PASS: {case['vals']} → {result}")
        else:
            dut._log.error(f"FAIL: {case['vals']} → {result}, expected {case['expected']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")