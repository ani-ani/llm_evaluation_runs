import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_adder(dut):
    test_cases = [
        # (length, list_values, expected_sum)
        (2, [4,88,0,0,0,0,0,0], 88),
        (6, [4,5,6,7,2,122,0,0], 122),
        (4, [4,0,6,7,0,0,0,0], 0),
        (4, [4,4,6,8,0,0,0,0], 12),
        (8, [1,2,1,4,1,8,1,16], 30),
        (4, [2,3,4,5,0,0,0,0], 0)
    ]
    
    passed = 0
    for length_val, lst_vals, expected in test_cases:
        # Assign inputs
        dut.length.value = length_val
        for i in range(8):
            dut.lst[i].value = lst_vals[i]
        
        # Wait for combinational logic to settle
        await Timer(1, units='ns')
        
        # Check result
        if dut.sum.value == expected:
            passed += 1
            dut._log.info(f"PASS: len={length_val} lst={lst_vals} sum={expected}")
        else:
            dut._log.error(f"FAIL: len={length_val} lst={lst_vals}. Got sum={dut.sum.value}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"Test summary: {passed}/{total} ({passed/total*100:.0f}%) passed")
    assert passed == total, f"{passed}/{total} tests passed"