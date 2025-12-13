import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import math

@cocotb.test()
async def test_rounded_avg(dut):
    test_cases = [
        (1, 5, 3),    # "0b11"
        (7, 5, -1),   # invalid
        (5, 5, 5),    # "0b101"
        (10, 20, 15), # "0b1111"
        (20, 23, 22), # avg=21.5->22 (0b000010110)
        (15, 20, 17), # avg=17.5->18 (0b000010010)
        (255, 255, 255) # edge case
    ]
    passed = 0
    
    for n, m, expected in test_cases:
        dut.n.value = n
        dut.m.value = m
        await Timer(1, units='ns')
        
        if expected == -1:
            if dut.result.value.signed_integer == -1:
                passed += 1
                dut._log.info(f"PASS: ({n},{m}) -> -1")
            else:
                dut._log.error(f"FAIL: ({n},{m}) got {dut.result.value.signed_integer}, expected -1")
        else:
            actual = dut.result.value.signed_integer
            if actual == expected:
                passed += 1
                dut._log.info(f"PASS: ({n},{m}) -> {bin(expected)}")
            else:
                dut._log.error(f"FAIL: ({n},{m}) got {bin(actual)} ({actual}), expected {bin(expected)}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"