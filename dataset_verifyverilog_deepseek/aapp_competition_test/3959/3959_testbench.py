import cocotb
from cocotb.triggers import Timer
from math import factorial

@cocotb.test()
async def test_evolution_counter(dut):
    # Define scaled test cases (original adapted with types 1-4)
    test_cases = [
        # Input 1 (scaled): Expect 1
        {'n': 2, 'm': 3, 'gym0_count': 2, 'gym1_count': 2,
         'gym0_types': [0,1,2,0], 'gym1_types': [1,2,3,0], 'expected': 1},
        # Input 2 (scaled): Expect 6 mod101 = 6
        {'n': 1, 'm': 3, 'gym0_count': 3, 'gym1_count': 0,
         'gym0_types': [0,1,2,0], 'gym1_types': [0,0,0,0], 'expected': 6},
        # Input 3 (original remains similar): Expect 2
        {'n': 2, 'm': 4, 'gym0_count': 2, 'gym1_count': 3,
         'gym0_types': [0,1,3,3], 'gym1_types': [1,2,3,3], 'expected': 2},
        # Edge case - all same type (n=2 gyms)
        {'n': 2, 'm': 2, 'gym0_count': 3, 'gym1_count': 3,
         'gym0_types': [0,0,0,0], 'gym1_types': [0,0,0,0], 'expected': 1}
    ]
    passed = 0
    for case in test_cases:
        # Apply inputs
        dut.n.value = case['n']
        dut.m.value = case['m']
        dut.gym0_count.value = case['gym0_count']
        dut.gym1_count.value = case['gym1_count']
        for i in range(4):
            dut.gym0_types[i].value = case['gym0_types'][i]
            dut.gym1_types[i].value = case['gym1_types'][i]
        await Timer(100, units='ns')
        result = dut.count.value.integer 
        if result == case['expected']:
            passed += 1
        else:
            dut._log.error("Test failed: Got %d, Expected %d" % (result, case['expected']))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))