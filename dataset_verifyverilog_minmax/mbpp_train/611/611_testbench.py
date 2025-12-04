import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_max_col(dut):
    test_cases = [
        # Test 1 Original: matrix=[[5,6,7],[1,3,5],[8,9,19]] col=2 -> 19
        {"rows": ((5,6,7), (1,3,5), (8,9,19)), "col": 2, "expected": 19},
        # Test 2 Original: matrix=[[6,7,8],[2,4,6],[9,10,20]] col=1 -> 10
        {"rows": ((6,7,8), (2,4,6), (9,10,20)), "col": 1, "expected": 10},
        # Test 3 Original: matrix=[[7,8,9],[3,5,7],[10,11,21]] col=1 -> 11
        {"rows": ((7,8,9), (3,5,7), (10,11,21)), "col": 1, "expected": 11}
    ]
    
    passed = 0
    for case in test_cases:
        dut.row0.value = LogicArray(case["rows"][0]).integer
        dut.row1.value = LogicArray(case["rows"][1]).integer
        dut.row2.value = LogicArray(case["rows"][2]).integer
        dut.col_idx.value = case["col"]
        await Timer(1, units='ns')
        
        if int(dut.max_val.value) == case["expected"]:
            passed += 1
            dut._log.info(f"PASS: Col {case['col']} max={case['expected']}")
        else:
            dut._log.error(f"FAIL: Got {int(dut.max_val.value)}, expected {case['expected']} for col {case['col']}")
            
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")