import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

day_map = {
    'monday': 0,
    'tuesday': 1,
    'wednesday': 2,
    'thursday': 3,
    'friday': 4,
    'saturday': 5,
    'sunday': 6
}

def get_expected(d1_str, d2_str):
    d1 = day_map[d1_str]
    d2 = day_map[d2_str]
    diff = (d2 - d1) % 7
    return 1 if diff in [0, 2, 3] else 0

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_calendar_logic(dut):
    # Test all pairs of days
    for d1_str, d1_val in day_map.items():
        for d2_str, d2_val in day_map.items():
            # Set inputs
            dut.day1.value = clamp_to_width(d1_val, 3)
            dut.day2.value = clamp_to_width(d2_val, 3)
            
            # Wait for propagation
            await Timer(10, units='ns')
            
            # Check output
            if not is_value_defined(dut.possible.value):
                raise TestFailure(f"Output undefined for {d1_str} -> {d2_str}")
            
            result = int(dut.possible.value)
            expected = get_expected(d1_str, d2_str)
            
            if result != expected:
                raise TestFailure(f"Mismatch for {d1_str} -> {d2_str}: Expected {expected}, Got {result}")