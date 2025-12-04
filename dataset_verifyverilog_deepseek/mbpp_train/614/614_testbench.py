import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_tuple_sum(dut):
    test_cases = [
        # Test 1: [(1,3), (5,6,7), (2,6)] = 1+3+5+6+7+2+6 = 30
        (
            [0b110, 0b111, 0b110],
            [[1,3,0], [5,6,7], [2,6,0]],
            30
        ),
        # Test 2: [(2,4), (6,7,8), (3,7)] = 2+4+6+7+8+3+7 = 37
        (
            [0b110, 0b111, 0b110],
            [[2,4,0], [6,7,8], [3,7,0]],
            37
        ),
        # Test 3: [(3,5), (7,8,9), (4,8)] = 3+5+7+8+9+4+8 = 44
        (
            [0b110, 0b111, 0b110],
            [[3,5,0], [7,8,9], [4,8,0]],
            44
        ),
        # Edge case: empty elements
        (
            [0b100, 0b001, 0b010],
            [[9,0,0], [0,0,4], [0,6,0]],
            19  # 9+4+6
        )
    ]
    
    passed = 0
    for valid, data, expected in test_cases:
        # Set validity matrix
        for i in range(3):
            dut.valid_matrix_i.value = LogicArray(valid[i])
            
            # Set data matrix
            for j in range(3):
                dut.data_matrix_i_j.value = data[i][j]
        
        await Timer(1, units='ns')
        
        if dut.total_sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: Sum={dut.total_sum.value}, expected {expected}")
        else:
            dut._log.error(f"FAIL: Got {dut.total_sum.value}, expected {expected} for inputs {valid}/{data}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")