import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_tuple_to_int(dut):
    test_cases = [
        # (tuple, expected)
        ((0,1,2,3), 123),
        ((0,4,5,6), 456),
        ((0,5,6,7), 567),
        ((1,0,0,0), 1000),
        ((9,9,9,9), 9999)
    ]
    passed = 0
    
    for tpl, expected in test_cases:
        # Pack four digits into 16-bit vector
        packed = (tpl[0] << 12) | (tpl[1] << 8) | (tpl[2] << 4) | tpl[3]
        dut.digits.value = packed
        
        await Timer(1, units='ns')
        
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {tpl} => {expected}")
        else:
            dut._log.error(f"FAIL: {tpl} => Got {int(dut.result.value)}, Expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    
    assert passed == len(test_cases), "Some test cases failed"