import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_rear_extract(dut):
    # (string positions replaced with 0 - not used in hardware)
    test_cases = [
        # Input: ((1,0,21), (2,0,20), (3,0,19)) | Expected: [21,20,19]
        {"in": [1,0,21, 2,0,20, 3,0,19], "exp": [21,20,19]},
        # Input: ((1,0,36), (2,0,25), (3,0,45)) | Expected: [36,25,45]
        {"in": [1,0,36, 2,0,25, 3,0,45], "exp": [36,25,45]},
        # Input: ((1,0,14), (2,0,36), (3,0,56)) | Expected: [14,36,56]
        {"in": [1,0,14, 2,0,36, 3,0,56], "exp": [14,36,56]}
    ]
    
    passed = 0
    for case in test_cases:
        # Set all inputs
        dut.tuple0_e0.value = case["in"][0]
        dut.tuple0_e1.value = case["in"][1]
        dut.tuple0_e2.value = case["in"][2]
        dut.tuple1_e0.value = case["in"][3]
        dut.tuple1_e1.value = case["in"][4]
        dut.tuple1_e2.value = case["in"][5]
        dut.tuple2_e0.value = case["in"][6]
        dut.tuple2_e1.value = case["in"][7]
        dut.tuple2_e2.value = case["in"][8]
        
        await Timer(1, units='ns')
        
        result = [dut.out0.value, dut.out1.value, dut.out2.value]
        if result == case["exp"]:
            passed += 1
            dut._log.info(f"PASS: Output {result} == Expected {case['exp']}")
        else:
            dut._log.error(f"FAIL: Output {result} != Expected {case['exp']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")