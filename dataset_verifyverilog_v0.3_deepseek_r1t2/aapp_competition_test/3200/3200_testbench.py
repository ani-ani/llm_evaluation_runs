import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions (as per guidelines)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Convert float to Q16.16 fixed-point
def float_to_fixed(f, frac_bits=16):
    return int(f * (1 << frac_bits))

# Convert Q16.16 to float
def fixed_to_float(fixed, frac_bits=16):
    return fixed / (1 << frac_bits)

# Compute total time for given parameters (Python reference)
def compute_total_time(n, lights):
    """
    lights: list of tuples (t, g, r) for each light
    Returns total time in seconds (float)
    """
    SQRT_2000 = math.sqrt(2000.0)  # time to travel 1 km from rest
    
    current_time = 0.0  # start_delay = 0
    current_velocity = 0.0
    
    for i in range(n-1):
        t_i, g_i, r_i = lights[i]
        period = g_i + r_i
        
        # Time to travel 1 km with current velocity
        if current_velocity == 0.0:
            seg_time = SQRT_2000
        else:
            seg_time = math.sqrt(current_velocity**2 + 2000.0) - current_velocity
        
        arrival_time = current_time + seg_time
        
        # Phase within light cycle
        phase = arrival_time % period
        
        # Check if green
        if phase >= t_i and phase <= t_i + g_i:  # inclusive at both ends
            # Pass without stopping
            current_velocity += seg_time
            current_time = arrival_time
        else:
            # Wait until next green
            if phase <= t_i:
                wait = t_i - phase
            else:
                wait = t_i + period - phase
            current_time = arrival_time + wait
            current_velocity = 0.0
    
    # Final segment to end
    if current_velocity == 0.0:
        seg_time = SQRT_2000
    else:
        seg_time = math.sqrt(current_velocity**2 + 2000.0) - current_velocity
    
    total_time = current_time + seg_time
    return total_time

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_traffic_light_time(dut):
    """Test traffic_light_time module with various inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # n, lights, expected_time (seconds)
        (1, [], 44.72135955),
        (2, [(50, 45, 45)], 68.52419365),
        (2, [(25, 45, 45)], 63.2455532),
    ]
    
    for i, (n, lights, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: n={n}, lights={lights}")
        
        # Set n
        dut.n.value = n
        
        # Set light parameters
        for idx, (t, g, r) in enumerate(lights):
            if has_signal(dut, f't_{idx}'):
                getattr(dut, f't_{idx}').value = clamp_to_width(t, 8)
                getattr(dut, f'g_{idx}').value = clamp_to_width(g, 8)
                getattr(dut, f'r_{idx}').value = clamp_to_width(r, 8)
            else:
                # If using arrays
                dut.t_arr[idx].value = clamp_to_width(t, 8)
                dut.g_arr[idx].value = clamp_to_width(g, 8)
                dut.r_arr[idx].value = clamp_to_width(r, 8)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 10000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.total_time.value):
            raise TestFailure(f"Output total_time is undefined")
        
        result_fixed = int(dut.total_time.value)
        result_float = fixed_to_float(result_fixed)
        
        # Compare with expected (allow tolerance)
        error = abs(result_float - expected)
        if error > 1e-6:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {result_float} (error {error})")
        
        dut._log.info(f"  PASS: time = {result_float}")
    
    dut._log.info("All tests passed!")
