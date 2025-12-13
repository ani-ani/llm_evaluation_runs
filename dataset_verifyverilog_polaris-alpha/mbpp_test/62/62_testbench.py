import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_min_finder(dut):
    # Test cases adapted for 8-bit width and 8-element max
    test_cases = [
        ([10,20,1,45,99,0,0,0], 5, 1),   # Original Test1 modified
        ([1,2,3,255,255,255,255,255], 3, 1),  # Original Test2 with padding
        ([45,46,50,60,0,0,0,0], 4, 45),  # Original Test3 shortened
        ([255,254,1,0,2,3,4,5], 8, 0),   # Edge: zero value
        ([128,129,255,127,0,1,2,3], 2, 128) # Partial elements check
    ]
    
    passed = 0
    for idx, (numbers, count, expected) in enumerate(test_cases):
        # Set array inputs
        for i in range(8):
            dut.numbers[i].value = numbers[i]
        dut.count.value = count
        
        await Timer(1, units='ns')
        
        actual = int(dut.min_num.value)
        if actual == expected:
            passed += 1
            dut._log.info(f"Test {idx} PASS: {numbers[:count]} -> min={expected}")
        else:
            dut._log.error(f"Test {idx} FAIL: {numbers[:count]} gave {actual}, expected {expected}")
    
    # Special case: empty array (should return all 1's)
    dut.count.value = 0
    await Timer(1, units='ns')
    if dut.min_num.value == 255:
        passed += 1
        dut._log.info("PASS: Empty array returned 0xFF")
    else:
        dut._log.error(f"FAIL: Empty array returned {dut.min_num.value}, expected 255")
    
    total = len(test_cases) + 1
    dut._log.info(f"{passed}/{total} tests passed")