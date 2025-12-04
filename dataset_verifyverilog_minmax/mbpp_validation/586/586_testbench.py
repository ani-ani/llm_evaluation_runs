import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_array_rotator(dut):
    test_cases = [
        # Test 1 (N=2)
        {"n":2, "arr":[12,10,5,6,52,36,0,0], "expected":[5,6,52,36,0,0,12,10]},
        # Test 2 (N=1)
        {"n":1, "arr":[1,2,3,4,0,0,0,0], "expected":[2,3,4,0,0,0,0,1]},
        # Test 3 (N=3)
        {"n":3, "arr":[0,1,2,3,4,5,6,7], "expected":[3,4,5,6,7,0,1,2]},
        # Edge case (N=0)
        {"n":0, "arr":[9,8,7,6,5,4,3,2], "expected":[9,8,7,6,5,4,3,2]},
        # Max rotation (N=7)
        {"n":7, "arr":[10,20,30,40,50,60,70,80], "expected":[80,10,20,30,40,50,60,70]}
    ]

    passed = 0
    for test in test_cases:
        dut.n.value = test["n"]
        for i in range(8):
            dut.arr[i].value = test["arr"][i]
        await Timer(1, units='ns')
        result = [dut.result[i].value for i in range(8)]

        if result == test["expected"]:
            passed += 1
            dut._log.info(f"PASS: n={test['n']} input={test['arr']} output={result}")
        else:
            dut._log.error(f"FAIL: n={test['n']} input={test['arr']} output={result}, expected {test['expected']}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)