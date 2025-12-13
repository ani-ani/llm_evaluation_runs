import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_empty_list(dut):
    test_cases = [
        (4, [0,0,0,0,0,1,1,1]),  # N=5
        (5, [0,0,0,0,0,0,1,1]),  # N=6
        (6, [0,0,0,0,0,0,0,1])   # N=7
    ]
    passed = 0
    for length, expected in test_cases:
        dut.length.value = length
        await Timer(1, units='ns')
        result = [dut.arr[i].value for i in range(8)]
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: length={length} → {result}")
        else:
            dut._log.error(f"FAIL: length={length} got {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")