import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_sort_third(dut):
    # Test cases adapted to 12 elements (pad with zeros where needed)
    test_cases = [
        # Original cases padded to 12 elements
        ([1,2,3]+[0]*9, [1,2,3]+[0]*9),
        ([5,3,-5,2,-3,3,9,0,123,1,-10,0], [ -10,3,-5,2,-3,3, 0,0,1,1,123,0]),
        # Edge cases
        ([10,-20,30,40,50,60,70,80,90,100,110,120], [ -20,-20,30, 70,50,60, 90,80,90, 10,110,120]),
        ([5,6,3,4,8,9,2,0,0,0,0,0], [2,6,3,4,8,9,5,0,0,0,0,0])
    ]

    passed = 0
    for inp, expected in test_cases:
        # Pack to 96-bit vector (12*8 bits)
        packed_in = 0
        for i, val in enumerate(inp):
            packed_in |= (val & 0xFF) << ((11-i)*8)
        
        dut.arr_in.value = packed_in
        await Timer(1, units='ns')  # Allow comb propagation
        
        # Unpack result
        result = []
        for i in range(12):
            val = (dut.arr_out.value >> ((11-i)*8)) & 0xFF
            if val & 0x80:  # Sign extend
                val -= 0x100
            result.append(val)

        # Check
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Input {inp} -> Output {result}")
        else:
            dut._log.error(f"FAIL: Input {inp} -> Got {result}, Expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")