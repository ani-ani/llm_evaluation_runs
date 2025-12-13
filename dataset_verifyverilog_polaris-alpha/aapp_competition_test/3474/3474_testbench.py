import cocotb
from cocotb.triggers import Timer
import numpy as np

# Q16.16 conversion helpers
def float_to_q16_16(val):
    return int(val * (1 << 16)) & 0xFFFFFFFF

def q16_16_to_float(val):
    return val.signed_integer / (1 << 16)

@cocotb.test()
async def test_laser_reflection(dut):
    test_cases = [
        # First test case: 5 10 10 10 10 0 (should hit negative-infinity to 0)
        {
            'input': [5, 10, 10, 10, 10, 0],
            'output': {'valid': 1, 'inf_low': 1, 'inf_high': 0, 'y_low': 0, 'y_high': 0}
        },
        # Second test case: 5 10 10 5 10 0 (should hit 5 to 12.5)
        {
            'input': [5, 10, 10, 5, 10, 0],
            'output': {'valid': 1, 'inf_low': 0, 'inf_high': 0,
                      'y_low': 5.0, 'y_high': 12.5}
        },
        # Third test case: 6 10 10 10 10 0 (negative-infinity to -5)
        {
            'input': [6, 10, 10, 10, 10, 0],
            'output': {'valid': 1, 'inf_low': 1, 'inf_high': 0, 'y_low': -5.0, 'y_high': -5.0}
        },
        # Fourth test case: 10 10 20 20 20 10 (can't hit)
        {
            'input': [10, 10, 20, 20, 20, 10],
            'output': {'valid': 0, 'inf_low': 0, 'inf_high': 0, 'y_low': 0, 'y_high': 0}
        }
    ]

    passed = 0
    tolerance = 0.0002  # 0.0001 accuracy + margin

    for case in test_cases:
        # Apply inputs
        dut.x1.value = float_to_q16_16(case['input'][0])
        dut.y1.value = float_to_q16_16(case['input'][1])
        dut.x2.value = float_to_q16_16(case['input'][2])
        dut.y2.value = float_to_q16_16(case['input'][3])
        dut.px.value = float_to_q16_16(case['input'][4])
        dut.py.value = float_to_q16_16(case['input'][5])

        await Timer(100, units='ns')  # Allow combinational propagation

        # Check outputs
        valid = dut.valid_hit.value
        inf_low = dut.inf_low.value
        inf_high = dut.inf_high.value
        y_low = q16_16_to_float(dut.y_low.value)
        y_high = q16_16_to_float(dut.y_high.value)

        expected = case['output']

        # Check validity first
        if valid != expected['valid']:
            dut._log.error(f"Validity mismatch: Got {valid}, expected {expected['valid']}")
            continue

        # If invalid hit, skip other checks
        if valid == 0:
            passed += 1
            continue

        # Check infinity flags
        if inf_low != expected['inf_low'] or inf_high != expected['inf_high']:
            dut._log.error(f"Inf flags mismatch: Got (low={inf_low}, high={inf_high})"
                           f", expected (low={expected['inf_low']}, high={expected['inf_high']})")
            continue

        # Verify finite bounds with tolerance
        check_low = True
        check_high = True
        if inf_low == 1:
            check_low = False
        if inf_high == 1:
            check_high = False

        fail = False
        if check_low:
            if abs(y_low - expected['y_low']) > tolerance:
                dut._log.error(f"Y_low mismatch: Got {y_low:.5f}, expected {expected['y_low']:.5f}")
                fail = True
        if check_high:
            if abs(y_high - expected['y_high']) > tolerance:
                dut._log.error(f"Y_high mismatch: Got {y_high:.5f}, expected {expected['y_high']:.5f}")
                fail = True

        if not fail:
            passed += 1

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
