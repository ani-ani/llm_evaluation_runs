import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_pairwise(dut):
    test_cases = [
        # Test 1: Original size 5
        {'in': [1,5,7,8,10,0,0,0], 'exp': [6,12,15,18,0,0,0]},
        # Test 2: Original size 5
        {'in': [2,6,8,9,11,0,0,0], 'exp': [8,14,17,20,0,0,0]},
        # Test 3: Original size 5
        {'in': [3,7,9,10,12,0,0,0], 'exp': [10,16,19,22,0,0,0]},
        # Additional edge cases
        {'in': [15,15,15,15,15,15,15,15], 'exp': [30,30,30,30,30,30,30,0]},
        {'in': [0,0,0,0,0,0,0,0], 'exp': [0,0,0,0,0,0,0,0]}
    ]
    passed = 0
    for case in test_cases:
        dut.in_array.value = case['in']
        await Timer(1, units='ns')
        result = dut.out_array.value
        # Only check N-1 elements where input was non-zero
        valid = next((i for i,v in enumerate(case['in'][1:8]) if v == 0), 7) + 1
        for i in range(valid):
            if int(result[i]) != case['exp'][i]:
                dut._log.error(f"FAIL: Input {case['in']} 
Expected {case['exp']}
Got {result}")
                break
        else:
            passed += 1
            dut._log.info(f"PASS: Input {case['in']} → {result}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")