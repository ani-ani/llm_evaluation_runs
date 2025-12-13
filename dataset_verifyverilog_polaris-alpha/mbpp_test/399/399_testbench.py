import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_tuple_xor(dut):
    test_cases = [
        # Test 1: ((10,4,6,9), (5,2,3,3) → (15,6,5,10))
        ([10,4,6,9], [5,2,3,3], [15,6,5,10]),
        # Test 2: ((11,5,7,10), (6,3,4,4) → (13,6,3,14))
        ([11,5,7,10], [6,3,4,4], [13,6,3,14]),
        # Test 3: ((12,6,8,11), (7,4,5,6) → (11,2,13,13))
        ([12,6,8,11], [7,4,5,6], [11,2,13,13])
    ]
    passed = 0
    for idx, (t1, t2, expected) in enumerate(test_cases):
        for i in range(4):
            dut.tuple1[i].value = t1[i]
            dut.tuple2[i].value = t2[i]
        await Timer(1, units='ns')
        result = [int(dut.result[i].value) for i in range(4)]
        if result == expected:
            passed += 1
            dut._log.info(f"Test {idx+1} PASSED")
        else:
            dut._log.error(f"Test {idx+1} FAILED: Got {result}, expected {expected}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")

# Note: Some simulators require array as LogicArray assignments
# If your simulator doesn't support direct array assignment, use:
# dut.tuple1.value = LogicArray(t1)
# dut.tuple2.value = LogicArray(t2)