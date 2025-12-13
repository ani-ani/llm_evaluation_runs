import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_debt_resolution(dut):
    test_cases = [
        {"valid": 0b1111, "a_id": [1,0,3,2], "b_amt": [100,100,70,70], "expected": 170},
        {"valid": 0b111,  "a_id": [1,2,1],   "b_amt": [120,50,80],  "expected": 150},
        {"valid": 0b11111, "a_id": [2,2,3,4,2], "b_amt": [30,20,100,40,60], "expected": 110},
        {"valid": 0b11,   "a_id": [1,0],     "b_amt": [100,100],  "expected": 100}
    ]
    passed = 0
    
    for case in test_cases:
        dut.valid_mask.value = case["valid"]
        for i in range(8):
            # Only set valid entries, others don't care
            if i < len(case["a_id"]):
                dut.a_id[i].value = case["a_id"][i]
                dut.b_amount[i].value = case["b_amt"][i]
            else:
                dut.a_id[i].value = 0
                dut.b_amount[i].value = 0
        
        await Timer(1, units='ns')
        
        if dut.total_min.value == case["expected"]:
            passed += 1
        else:
            dut._log.error("Test failed: Valid=%#x, Got %d, Expected %d" % 
                          (case["valid"], dut.total_min.value, case["expected"]))
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
