import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_and_tuples(dut):
    test_cases = [
        # Test 1 - Original values
        (((10, 4, 6, 9), (5, 2, 3, 3)), (0, 0, 2, 1)),
        # Test 2
        (((1, 2, 3, 4), (5, 6, 7, 8)), (1, 2, 3, 0)),
        # Test 3
        (((8, 9, 11, 12), (7, 13, 14, 17)), (0, 9, 10, 0)),
        # Edge cases
        (((0, 0, 0, 0), (31, 31, 31, 31)), (0, 0, 0, 0)),
        (((31, 31, 31, 31), (31, 31, 31, 31)), (31, 31, 31, 31))
    ]
    
    passed = 0
    for (t1, t2), expected in test_cases:
        # Convert tuples to packed format
        packed_t1 = (t1[3] << 15) | (t1[2] << 10) | (t1[1] << 5) | t1[0]
        packed_t2 = (t2[3] << 15) | (t2[2] << 10) | (t2[1] << 5) | t2[0]
        
        dut.tuple1.value = packed_t1
        dut.tuple2.value = packed_t2
        await Timer(1, units='ns')
        
        # Unpack result
        result = []
        result.append(dut.result_tuple.value & 0x1F)
        result.append((dut.result_tuple.value >> 5) & 0x1F)
        result.append((dut.result_tuple.value >> 10) & 0x1F)
        result.append((dut.result_tuple.value >> 15) & 0x1F)
        
        if tuple(result) == expected:
            passed += 1
            dut._log.info(f"PASS: ({t1}) & ({t2}) = {result}")
        else:
            dut._log.error(f"FAIL: ({t1}) & ({t2}) = {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")