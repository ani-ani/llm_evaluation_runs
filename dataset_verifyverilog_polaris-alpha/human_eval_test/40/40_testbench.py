import cocotb
from cocotb.triggers import Timer
import itertools

@cocotb.test()
async def test_triples(dut):
    # Adapted test cases (padded with zeros for 8 elements, maintaining original values)
    test_cases = [
        ([1, 3, 5, 0, 0, 0, 0, 0], 0),    # Original: False
        ([1, 3, 5, -1, 0, 0, 0, 0], 0),  # Original: False
        ([1, 3, -2, 1, 0, 0, 0, 0], 1),  # Original: True (1,3,-2)
        ([1, 2, 3, 7, 0, 0, 0, 0], 0),    # Original: False
        ([2,4,-5,3,9,7,0,0], 1)          # Original: True (2,-5,3)
    ]

    passed = 0
    for arr, expected in test_cases:
        # Pad input to 8 elements if needed
        padded_arr = arr + [0]*(8 - len(arr))
        dut.arr.value = [int(x & 0xFF) for x in padded_arr]  # Convert to 8-bit 2's complement
        await Timer(1, units='ns')
        
        if dut.out.value == expected:
            passed += 1
            dut._log.info(f"PASS: {arr} => {expected}")
        else:
            dut._log.error(f"FAIL: {arr} => {dut.out.value} (expected {expected})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")