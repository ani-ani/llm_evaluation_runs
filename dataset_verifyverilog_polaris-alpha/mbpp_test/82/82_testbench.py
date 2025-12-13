import cocotb
from cocotb.triggers import Timer
from fixed_point_models import float_to_q16_16, q16_16_to_float

@cocotb.test()
async def test_sphere(dut):
    # Test cases adapted to fixed-point
    test_cases = [
        (10.0, 4188.7902),
        (25.0, 65449.8469),
        (20.0, 33510.3216),
        (0.5, 0.5236),  # Additional edge case
        (15.625, 15977.1429)  # Test fractional input
    ]
    passed = 0
    tolerance = 150  # ~0.002 tolerance in Q16.16 units (150/65536 ≈ 0.002)
    
    for r_float, expected_float in test_cases:
        r_fp = float_to_q16_16(r_float)
        expected_fp = float_to_q16_16(expected_float)
        
        dut.radius.value = r_fp
        await Timer(5, units='ns')  # Allow propagation delay
        
        actual = dut.volume.value.integer
        diff = abs(actual - expected_fp)
        
        if diff <= tolerance:
            passed += 1
            dut._log.info(f"PASS: r={r_float} vol={q16_16_to_float(actual)} (expected {expected_float}, diff={diff})")
        else:
            dut._log.error(f"FAIL: r={r_float} vol_z=q16_16_to_float(actual) (expected {expected_float}, diff={diff})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")