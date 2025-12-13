import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import ast

@cocotb.test()
async def test_tuple_mult(dut):
    # Convert test cases to hardware-friendly format
    test_cases = [
        {
            "t1": [[1,3], [4,5], [2,9], [1,10]],
            "t2": [[6,7], [3,9], [1,1], [7,3]],
            "exp": [[6,21], [12,45], [2,9], [7,30]]
        },
        {
            "t1": [[2,4], [5,6], [3,10], [2,11]],
            "t2": [[7,8], [4,10], [2,2], [8,4]],
            "exp": [[14,32], [20,60], [6,20], [16,44]]
        },
        {
            "t1": [[3,5], [6,7], [4,11], [3,12]],
            "t2": [[8,9], [5,11], [3,3], [9,5]],
            "exp": [[24,45], [30,77], [12,33], [27,60]]
        }
    ]

    passed = 0
    for case in test_cases:
        # Load inputs
        for i in range(4):
            for j in range(2):
                # Workaround for Verilator limitations with multi-dim arrays
                flat_idx = i*2 + j
                dut.test_tup1_flat_idx.value = case["t1"][i][j]
                dut.test_tup2_flat_idx.value = case["t2"][i][j]
        
        await Timer(1, units='ns')
        
        # Check outputs
        correct = True
        for i in range(4):
            for j in range(2):
                flat_idx = i*2 + j
                actual = dut.res_flat_idx.value.signed_integer
                expected = case["exp"][i][j]
                if actual != expected:
                    dut._log.error(f"Mismatch at [{i}][{j}]: Expected {expected}, Got {actual}")
                    correct = False
        
        if correct:
            passed += 1
            dut._log.info(f"Passed test case {passed}")
        else:
            dut._log.error(f"Failed test case with inputs {case['t1']} and {case['t2']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")