import cocotb
from cocotb.triggers import Timer
from cocotb.types import Log

@cocotb.test()
async def test_pos_counter(dut):
    test_cases = [
        ([1,-2,3,-4], 2),  # Original Test 1
        ([3,4,5,-1], 3),   # Original Test 2
        ([1,2,3,4], 4),    # Original Test 3
        ([-1,-2,-3,-4], 0) # Edge case: all negatives
    ]
    
    passed = 0
    for (numbers, expected) in test_cases:
        # Convert Python list to 4-element packed array
        # Numbers are mapped as 4-bit signed: 1=0b0001, -2=0b1110 etc.
        packed = 0
        for i, num in enumerate(numbers):
            # Convert to 4-bit signed representation
            if num < 0:
                num = (1 << 4) + num  # Two's complement         
            packed |= (num & 0xF) << (i*4)
            
        dut.numbers.value = packed
        await Timer(1, units='ns')
        
        if dut.pos_count.value == expected:
            passed += 1
            dut._log.info(f"PASS: {numbers} => {dut.pos_count.value}")
        else:
            dut._log.error(f"FAIL: {numbers} => {dut.pos_count.value}, expected {expected}")
    
    # Convert 3-bit output count to integer
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")