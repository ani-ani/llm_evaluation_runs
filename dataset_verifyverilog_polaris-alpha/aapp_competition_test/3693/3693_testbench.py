import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_squares(dut):
    test_cases = [
        # Format: (square1, square2, expected_result)
        # Example 1: Square2 entirely inside square1
        ((0,0,6,0,6,6,0,6), (1,3,3,5,5,3,3,1), 1),
        # Example 2: No intersection
        ((0,0,6,0,6,6,0,6), (7,3,9,5,11,3,9,1), 0),
        # Example 3: Overlapping edges
        ((6,0,6,6,0,6,0,0), (7,4,4,7,7,10,10,7), 1),
        # Edge case: single point contact
        ((-100,-100,100,-100,100,100,-100,100), (-100,0,0,100,100,0,0,-100), 1),
        # Random test case: small squares
        ((3,45,19,45,19,61,3,61), (-29,45,-13,29,3,45,-13,61), 1)
    ]
    passed = 0
    
    for (sq1, sq2, expected) in test_cases:
        for i in range(8):
            dut.square1[i].value = sq1[i] if i < len(sq1) else 0
            dut.square2[i].value = sq2[i] if i < len(sq2) else 0
        await Timer(10, units='ns')
        result = dut.intersect.value
        if result != expected:
            dut._log.error(f"Test failed: Input1={sq1}, Input2={sq2} => {result}, expected {expected}")
        else:
            passed += 1
    
    # Additional randomized tests within range
    for _ in range(5):
        sq1 = tuple(random.randint(-100,100) for _ in range(8))
        sq2 = tuple(random.randint(-100,100) for _ in range(8))
        for i in range(8):
            dut.square1[i].value = sq1[i]
            dut.square2[i].value = sq2[i]
        await Timer(10, units='ns')
        dut._log.info(f"Random check: sq1={sq1}, sq2={sq2} => {dut.intersect.value}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed != len(test_cases):
        raise TestFailure(f"{passed}/{len(test_cases)} tests passed")