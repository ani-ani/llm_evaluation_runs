import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import struct

@cocotb.test()
async def test_even_filter(dut):
    # Test cases packed as (input_numbers, expected_mask)
    test_cases = [
        ([1,2,3,4,5,1,1,1], 0b00001010),  # Original [1,2,3,4,5] -> [2,4]
        ([4,5,6,7,8,0,1,1], 0b00110101),  # Original [4,5,6,7,8,0,1] -> [4,6,8,0]
        ([8,12,15,19,1,1,1,1], 0b00000011),  # Original [8,12,15,19] -> [8,12]
        ([127,0,255,42,100,99,15,8], 0b11010011)  # Additional test case
    ]
    passed = 0
    
    for numbers, expected in test_cases:
        # Pack numbers into 64-bit value
        packed = 0
        for i, num in enumerate(numbers):
            packed |= (num & 0xFF) << (i*8)
        dut.nums.value = packed
        
        await Timer(1, units='ns')
        
        actual = int(dut.mask.value)
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: Input={numbers} -> Mask=0b{actual:08b}")
        else:
            dut._log.error(f"FAIL: Input={numbers} Got 0b{actual:08b}, Expected 0b{expected:08b}")
    
    dut._log.info(f"Summary: {passed}/{len(test_cases)} tests passed")