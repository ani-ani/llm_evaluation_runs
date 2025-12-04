import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import numpy as np

@cocotb.test()
async def test_costume_solver(dut):
    test_inputs = [
        # Test case 1 (Original sample scaled)
        {'n': 5, 'l': [1,1,3,3,3,0,0,0], 'r': [0,0,0,0,0,0,0,0], 'x': 0b01101, 'expected': 0},
        # Test case 2 (Original second sample scaled)
        {'n': 5, 'l': [3,0,1,1,0,0,0,0], 'r': [1,3,3,2,4,0,0,0], 'x': 0b11111, 'expected': 4}
    ]
    passed = 0

    for test in test_inputs:
        dut.n.value = test['n']
        for i in range(8):
            dut.l_array[i].value = test['l'][i]
            dut.r_array[i].value = test['r'][i]
            dut.x_array[i].value = (test['x'] >> i) & 1
        await Timer(1, units='ns')
        valid = dut.result.value
        if int(valid) % 1000000007 == test['expected']:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d got %d expected %d" % (test['n'], valid, test['expected']))
    dut._log.info("%d/%d tests passed" % (passed, len(test_inputs)))
