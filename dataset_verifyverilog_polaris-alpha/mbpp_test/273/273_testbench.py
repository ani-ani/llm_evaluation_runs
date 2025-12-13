import cocotb
from cocotb.triggers import Timer
import numpy as np

@cocotb.test()
async def test_subtractor(dut):
    test_cases = [
        # Test 1 (expanded to 4 elements)
        ((10, 4, 5, 0), (2, 5, 18, 0), (8, -1, -13, 0)),
        # Test 2 (expanded)
        ((11, 2, 3, 0), (24, 45, 16, 0), (-13, -43, -13, 0)),
        # Test 3 (expanded)
        ((7, 18, 9, 0), (10, 11, 12, 0), (-3, 7, -3, 0)),
        # Additional full-length test
        ((10, 20, 30, -64), (5, 10, 20, 32), (5, 10, 10, -96))
    ]
    
    passed = 0
    for idx, (t1, t2, expected) in enumerate(test_cases):
        # Set inputs as signed values
        for i in range(4):
            dut.tuple1[i].value = t1[i] if isinstance(t1[i], int) else 0
            dut.tuple2[i].value = t2[i] if isinstance(t2[i], int) else 0
        
        await Timer(1, units='ns')  # Wait for combinational logic
        
        success = True
        for i in range(4):
            actual = dut.result[i].value.signed_integer
            exp_val = expected[i] if i < len(expected) else 0
            
            if actual != exp_val:
                dut._log.error(f"Test {idx+1}[{i}] FAIL: {t1[i]}-{t2[i]}={actual}, expected {exp_val}")
                success = False
        
        if success:
            passed += 1
            dut._log.info(f"Test {idx+1} PASS")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")