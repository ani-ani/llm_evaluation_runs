import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_divisible_tuples(dut):
    test_cases = [
        # Test 1 (original test case 0 with list padded to 4 tuples)
        {'inputs': (6, [(6,24,12), (7,9,6), (12,18,21), (0,0,0)]), 'expected': 0b1111},  # Bitmask: tuple0 valid
        # Test case using numbers from test2
        {'inputs': (5, [(5,25,30), (4,2,3), (7,8,9), (10,20,5)]), 'expected': 0b1001},  # tuple0 and tuple3 valid
        # Test case using test3 numbers
        {'inputs': (4, [(7,9,16), (8,16,4), (19,17,18), (0,0,8)]), 'expected': 0b1010},  # tuple1 and tuple3 valid
        # Edge case with zero values
        {'inputs': (5, [(0,0,0), (5,10,0), (2,0,5), (15,5,10)]), 'expected': 0b1110},   # Last 3 tuples valid when zero allowed
        # No valid tuples case
        {'inputs': (3, [(1,2,4), (5,7,8), (11,13,17), (0,0,0)]), 'expected': 0b0000}     
    ]

    passed = 0
    for i, test in enumerate(test_cases):
        K, tuples = test['inputs']
        expected = test['expected']
        
        # Apply inputs
        dut.K.value = K
        dut.tuple0_0.value = tuples[0][0]
        dut.tuple0_1.value = tuples[0][1]
        dut.tuple0_2.value = tuples[0][2]
        dut.tuple1_0.value = tuples[1][0]
        dut.tuple1_1.value = tuples[1][1]
        dut.tuple1_2.value = tuples[1][2]
        dut.tuple2_0.value = tuples[2][0]
        dut.tuple2_1.value = tuples[2][1]
        dut.tuple2_2.value = tuples[2][2]
        dut.tuple3_0.value = tuples[3][0]
        dut.tuple3_1.value = tuples[3][1]
        dut.tuple3_2.value = tuples[3][2]
        
        await Timer(1, units='ns')
        
        result = dut.valid_tuples.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"Test {i+1}: PASS
  K={K}
  Input tuples={tuples}
  Result=0b{result:04b}, Expected=0b{expected:04b}")
        else:
            dut._log.error(f"Test {i+1}: FAIL
  K={K}
  Input tuples={tuples}
  Result=0b{result:04b}, Expected=0b{expected:04b}")
    
    dut._log.info(f"SUMMARY: {passed}/{len(test_cases)} tests passed")