import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_tuple_combinations(dut):
    test_cases = [
        # Test 1
        {
            "input": [(2,4), (6,7), (5,1), (6,10)],
            "expected": [(8,11), (7,5), (8,14), (11,8), (12,17), (11,11)]
        },
        # Test 2
        {
            "input": [(3,5), (7,8), (6,2), (7,11)],
            "expected": [(10,13), (9,7), (10,16), (13,10), (14,19), (13,13)]
        },
        # Test 3
        {
            "input": [(4,6), (8,9), (7,3), (8,12)],
            "expected": [(12,15), (11,9), (12,18), (15,12), (16,21), (15,15)]
        },
    ]
    
    passed = 0
    for test in test_cases:
        # Load inputs
        in_tuples = test["input"]
        dut.tuple_0_0.value = in_tuples[0][0]
        dut.tuple_0_1.value = in_tuples[0][1]
        dut.tuple_1_0.value = in_tuples[1][0]
        dut.tuple_1_1.value = in_tuples[1][1]
        dut.tuple_2_0.value = in_tuples[2][0]
        dut.tuple_2_1.value = in_tuples[2][1]
        dut.tuple_3_0.value = in_tuples[3][0]
        dut.tuple_3_1.value = in_tuples[3][1]
        
        # Allow time for comb logic to settle
        await Timer(1, units='ns')
        
        # Check all outputs
        results = [
            (dut.result_0_0.value.integer, dut.result_0_1.value.integer),
            (dut.result_1_0.value.integer, dut.result_1_1.value.integer),
            (dut.result_2_0.value.integer, dut.result_2_1.value.integer),
            (dut.result_3_0.value.integer, dut.result_3_1.value.integer),
            (dut.result_4_0.value.integer, dut.result_4_1.value.integer),
            (dut.result_5_0.value.integer, dut.result_5_1.value.integer)
        ]
        
        # Verify against expected
        match = True
        for i, (res, exp) in enumerate(zip(results, test["expected"])):
            if res != exp:
                dut._log.error(f"Combination {i} failed: Got {res}, Expected {exp}")
                match = False
                
        if match:
            passed += 1
            dut._log.info(f"PASS: Input {in_tuples}")
    
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} tests passed")