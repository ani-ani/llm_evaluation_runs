import cocotb
from cocotb.triggers import Timer
import numpy as np

@cocotb.test()
async def test_monotonic(dut):
    # Test cases adapted with padding and lengths
    test_cases = [
        (4, [1, 2, 4, 10, 10, 10, 10, 10], True),
        (4, [1, 20, 4, 10, 10, 10, 10, 10], False),
        (4, [4, 1, 0, -10, -10, -10, -10, -10], True),
        (4, [4, 1, 1, 0, 0, 0, 0, 0], True),
        (6, [1, 2, 3, 2, 5, 60, 60, 60], False),
        (4, [9, 9, 9, 9, 9, 9, 9, 9], True),
        (2, [-100, 100, 0, 0, 0, 0, 0, 0], False),
        (1, [42, 0, 0, 0, 0, 0, 0, 0], True)
    ]

    passed = 0
    for length, arr, expected in test_cases:
        # Convert to proper signed representation
        arr_signed = [x if x >=0 else (256 + x) for x in arr]
        
        dut.length.value = length
        for i in range(8):
            getattr(dut, f"arr_{i}").value = arr_signed[i]
        
        await Timer(1, units='ns')
        
        if dut.is_monotonic.value == expected:
            passed += 1
            dut._log.info(f"PASS: L={length}, arr={arr[:length]}
")
        else:
            dut._log.error(f"FAIL: L={length}, arr={arr[:length]} => {dut.is_monotonic.value}, expected {expected}
")
    
    # Summary must be outside loop
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)