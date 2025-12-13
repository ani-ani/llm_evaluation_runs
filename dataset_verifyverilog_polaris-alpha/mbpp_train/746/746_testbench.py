import cocotb
from cocotb.triggers import Timer
import numpy as np

@cocotb.test()
async def test_sector(dut):
    """Q16.16 test cases (expected = float_value * 65536) """
    test_cases = [
        # radius, angle, expected_area (or None)
        (4, 45, int(6.283185 * 65536)),  # ~411775
        (9, 45, int(31.808625 * 65536)),  # ~2084469
        (9, 361, None),
        (0, 180, 0),  # edge: zero radius
        (65535, 360, (3.141592 * 65535**2).astype(int) >> 16)  # max valid
    ]
    passed = 0
    
    for r, a, exp in test_cases:
        dut.radius.value = r
        dut.angle.value = a
        await Timer(1, units='ns')
        
        if exp is None:
            if dut.invalid.value != 1:
                dut._log.error(f"FAIL {r},{a}: Invalid not set")
            elif dut.area_q.value != 0xFFFFFFFF:
                dut._log.error(f"FAIL {r},{a}: Bad error code {hex(dut.area_q.value)}")
            else:
                passed += 1
                dut._log.info(f"PASS {r},{a}: Correctly invalid")
        else:
            if dut.invalid.value == 1:
                dut._log.error(f"FAIL {r},{a}: Incorrectly marked invalid")
            else:
                # Allow 1% tolerance for fixed-point approximation
                tolerance = abs(exp) // 100
                actual = dut.area_q.value.integer
                
                if abs(actual - exp) <= tolerance:
                    passed += 1
                    dut._log.info(f"PASS {r},{a}: {actual} vs {exp}")
                else:
                    dut._log.error(f"FAIL {r},{a}: {actual} vs {exp} (tol={tolerance})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")