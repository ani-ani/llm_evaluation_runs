import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_statue_rotator(dut):
    test_cases = [
        ([0,1,2,3,4,5,6,7], [0,2,3,4,5,6,7,1], 1),
        ([1,0,2,3,4,5,6,7], [0,1,2,3,4,5,6,7], 1),
        ([1,2,3,0,4,5,6,7], [0,3,2,1,4,5,6,7], 0),
        ([3,0,1,2,4,5,6,7], [0,1,2,4,5,6,7,3], 1),
        ([1,2,3,4,0,5,6,7], [0,1,3,2,4,5,6,7], 0)
    ]
    passed = 0
    for idx, tc in enumerate(test_cases):
        a_list, b_list, expected = tc
        for i in range(8):
            dut.a[i].value = a_list[i]
            dut.b[i].value = b_list[i]
        await Timer(1, units='ns')
        if dut.possible.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test case {idx} failed: Expected {expected}, got {dut.possible.value}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")