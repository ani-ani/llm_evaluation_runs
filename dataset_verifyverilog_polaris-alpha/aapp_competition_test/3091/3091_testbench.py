import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_kenken(dut):
    # Test cases (n m t op positions...)
    test_cases = [
        # m=2 subtraction case (valid pairs: (4,1), (1,4))
        (4, 2, 3, 1,  [[1,1], [1,2]], 2),
        # m=3 addition case (1+2+3=6, check row/col constraints)
        (4, 3, 6, 0,  [[0,0], [0,1], [1,0]], 6),
        # m=2 division case (valid: (4,2), (3,1) - but 3/1=3≠2, so only 4/2)
        (4, 2, 2, 3,  [[0,0], [0,1]], 1)
    ]
    passed = 0
    for idx, (n_val, m_val, t_val, op_val, positions, expected) in enumerate(test_cases):
        dut.n.value = n_val
        dut.m.value = m_val
        dut.t.value = t_val
        dut.op.value = op_val
        
        # Set position inputs
        dut.pos0_row.value = positions[0][0]
        dut.pos0_col.value = positions[0][1]
        dut.pos1_row.value = positions[1][0]
        dut.pos1_col.value = positions[1][1]
        if m_val == 3:
            dut.pos2_row.value = positions[2][0]
            dut.pos2_col.value = positions[2][1]
        else:
            dut.pos2_row.value = 0
            dut.pos2_col.value = 0
        
        await Timer(1, units='ns')
        
        if dut.count.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test {idx} failed: Got {dut.count.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")