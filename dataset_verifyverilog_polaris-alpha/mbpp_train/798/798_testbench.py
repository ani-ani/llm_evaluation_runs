import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_array_sum(dut):
    # Test cases adapted with zero padding for fixed-size array
    test_cases = [
        ([1, 2, 3] + [0]*5, 6),
        ([15, 12, 13, 10] + [0]*4, 50),
        ([0, 1, 2] + [0]*5, 3),
        ([255]*8, 2040),  # max value test
        ([0]*8, 0)  # all zeros test
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr_input, expected in test_cases:
        # Set array inputs
        for i in range(8):
            dut.arr[i].value = arr_input[i]
        
        await Timer(1, units='ns')
        
        if dut.sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: Sum {dut.sum.value} == {expected}")
        else:
            dut._log.error(f"FAIL: Input {arr_input} produced sum={dut.sum.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{total} tests passed")