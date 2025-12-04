import cocotb
from cocotb.triggers import Timer
import itertools

@cocotb.test()
async def test_palindrome(dut):
    # Adapted test cases (pad with zeros, keep original length)
    tests = [
        (8, [1,2,3,5,4,7,9,6], 4),
        (7, [1,2,3,4,3,2,2], 1),
        (3, [1,4,2], 1),
        (4, [1,4,4,2,0,0,0,0], 1),
        (5, [1,2,3,2,1,0,0,0], 0),
        (4, [3,1,1,3,0,0,0,0], 0),
        (1, [1,0,0,0,0,0,0,0], 0),
        (2, [0,1,0,0,0,0,0,0], 1)
    ]
    passed = 0
    
    for length, arr, expected in tests:
        dut.arr_len.value = length
        for i in range(8):
            dut.arr[i].value = arr[i]
        await Timer(1, units='ns')
        if dut.changes.value.integer == expected:
            passed += 1
            dut._log.info(f"PASS: len={length}, arr={arr[:length]}
=> {dut.changes.value} (expected {expected})")
        else:
            dut._log.error(f"FAIL: len={length}, arr={arr[:length]}
=> {dut.changes.value} != expected {expected}")
    
    # Results summary
    total = len(tests)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed} tests"