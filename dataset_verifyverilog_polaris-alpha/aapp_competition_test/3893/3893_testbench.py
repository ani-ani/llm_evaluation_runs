import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_count_roads(dut):
    tests = [
        # Test 1: Example input 1 (2 roads)
        {"x1":1, "y1":1, "x2":-1, "y2":-1,
         "a":[0,1,0,0,0,0,0,0],
         "b":[1,0,0,0,0,0,0,0],
         "c":[0,0,0,0,0,0,0,0],
         "expected":2},
        
        # Test 2: Example input 2 (3 roads, 2 separations)
        {"x1":1, "y1":1, "x2":-1, "y2":-1,
         "a":[1,0,1,0,0,0,0,0],
         "b":[0,1,1,0,0,0,0,0],
         "c":[0,0,-3,0,0,0,0,0],
         "expected":2},
        
        # Test 3: Single separating road
        {"x1":0, "y1":0, "x2":0, "y2":2,
         "a":[0,0,0,0,0,0,0,0],
         "b":[1,0,0,0,0,0,0,0],
         "c":[-1,0,0,0,0,0,0,0],
         "expected":1}
    ]
    passed = 0
    for test in tests:
        # Set inputs
        dut.x1.value = test["x1"]
        dut.y1.value = test["y1"]
        dut.x2.value = test["x2"]
        dut.y2.value = test["y2"]
        for i in range(8):
            dut.a[i].value = test["a"][i]
            dut.b[i].value = test["b"][i]
            dut.c[i].value = test["c"][i]
        await Timer(1, units='ns')
        if dut.count.value == test["expected"]:
            passed += 1
            dut._log.info("Test passed")
        else:
            dut._log.error(f"Test failed: Expected {test['expected']}, got {dut.count.value}")
    dut._log.info(f"{passed}/{len(tests)} tests passed")
