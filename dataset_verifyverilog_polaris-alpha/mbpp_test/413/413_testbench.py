import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_extractor(dut):
    # Converted test cases (original string example adapted to numerical representation)
    test_cases = [
        # Test 1: Extract element 0 (originally names, represented as numbers)
        (
            [
                [0x1111, 98, 99],
                [0x2222, 97, 96],
                [0x3333, 91, 94],
                [0x4444, 94, 98]
            ], 
            0,
            [0x1111, 0x2222, 0x3333, 0x4444]
        ),
        # Test 2: Extract element 2
        (
            [
                [0xAAAA, 98, 99],
                [0xBBBB, 97, 96],
                [0xCCCC, 91, 94],
                [0xDDDD, 94, 98]
            ],
            2,
            [99, 96, 94, 98]
        ),
        # Test 3: Extract element 1
        (
            [
                [0x1234, 98, 99],
                [0x5678, 97, 96],
                [0x9ABC, 91, 94],
                [0xDEF0, 94, 98]
            ],
            1,
            [98, 97, 91, 94]
        )
    ]
    
    passed = 0
    for tuples, n, expected in test_cases:
        # Flatten 3D array to 2D Verilog input format
        dut.tuples.value = sum((tuple for tuple in tuples), [])
        dut.n.value = n
        await Timer(1, units='ns')
        
        result = [dut.result.value[i] for i in range(4)]
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: n={n} => {result}")
        else:
            dut._log.error(f"FAIL: n={n} => {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)