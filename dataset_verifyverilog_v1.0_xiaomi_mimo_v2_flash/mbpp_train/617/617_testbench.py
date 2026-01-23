import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return value + (1 << bits)  # Assume unsigned handling for clamp
    return min(max_val, value)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Fixed point conversion (Q8.8)
def float_to_q8_8(f):
    return int(f * 256)

def q8_8_to_float(val):
    return val / 256.0

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_jumps(dut):
    """Test the min_Jumps module."""

    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.step_a.value = 0
    dut.step_b.value = 0
    dut.target_d.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: (step_a, step_b, target_d, expected_float)
    test_cases = [
        (3, 4, 11, 2.75),  # Note: Python logic gave 3.5 for 11/4? 
        # Wait, let's re-read the python logic: return (d + b - 1) / b 
        # For 11, 4: (11 + 4 - 1) / 4 = 14/4 = 3.5. 
        # Let's check the python code again. 
        # if (d >= b): return (d + b - 1) / b 
        # For Test 1: d=11, b=4. (11+3)/4 = 3.5. Correct.
        # Let's implement this exact logic.
        (3, 4, 11, 3.5),
        (3, 4, 0, 0.0),
        (11, 14, 11, 1.0),
        (10, 20, 15, 2.0), # 15 >= 20? No. 15 == 10? No. Else 2.0
        (5, 6, 25, 5.0), # 25 >= 6. (25+5)/6 = 30/6 = 5.0
    ]

    for i, (a, b, d, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: a={a}, b={b}, d={d}, expected={expected}")

        # Clamp inputs to 8 bits (just in case)
        a = clamp_to_width(a, 8)
        b = clamp_to_width(b, 8)
        d = clamp_to_width(d, 8)

        # Apply inputs
        dut.step_a.value = a
        dut.step_b.value = b
        dut.target_d.value = d

        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        max_cycles = 20
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")

        # Read result
        if not is_value_defined(dut.result.value):
             raise TestFailure(f"Test {i+1}: Result is undefined (X/Z)")

        raw_result = int(dut.result.value)
        result_float = q8_8_to_float(raw_result)

        # Compare
        # Allow small floating point tolerance
        if abs(result_float - expected) > 0.01:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result_float} (raw {raw_result})")

        dut._log.info(f"  PASS: Result {result_float}")
        await RisingEdge(dut.clk)  # Spacing
