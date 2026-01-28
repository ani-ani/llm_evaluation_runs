import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Include standard helpers (see template)
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Helper to convert float to Q16.16 fixed point
def float_to_q16_16(f):
    return int(f * 65536)

# Helper to convert Q16.16 to float
def q16_16_to_float(v):
    # Handle signed values if necessary, assuming input is Python int
    if v < 0: v = v + (1 << 32)
    return v / 65536.0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_taxi_expectation(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test Case 1: Square 0,0 0,1 1,1 1,0
    # Expected: 0.6666667
    dut.vertex_count.value = 4
    
    vertices_x = [0, 0, 1, 1]
    vertices_y = [0, 1, 1, 0]
    
    # Write vertices. For Verilog arrays, assign individually.
    # Assuming dut.vertex_x[i] and dut.vertex_y[i] structure for i in 0..15
    for i in range(16):
        x_val = vertices_x[i] if i < len(vertices_x) else 0
        y_val = vertices_y[i] if i < len(vertices_y) else 0
        # Convert to signed 16-bit if needed, but inputs are small
        # Check if signals exist as arrays
        if has_signal(dut, f'vertex_x[{i}]'):
            dut.vertex_x[i].value = x_val
        elif has_signal(dut, f'vertex_x_{i}'):
            getattr(dut, f'vertex_x_{i}').value = x_val
        
        if has_signal(dut, f'vertex_y[{i}]'):
            dut.vertex_y[i].value = y_val
        elif has_signal(dut, f'vertex_y_{i}'):
            getattr(dut, f'vertex_y_{i}').value = y_val

    cocotb.log.info("Starting calculation for Square...")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined")
        
    result_val = int(dut.result.value)
    
    # Convert Q16.16 to float
    # If result is 32-bit, Python int is fine. Check for sign extension if HDL is signed.
    # Assuming unsigned 32-bit int for Q16.16 representation
    expected_fixed = float_to_q16_16(0.666666666666667)
    
    # Allow some error for Monte Carlo approx (though the spec implies a deterministic result or strict FP)
    # If the HDL is Monte Carlo, error can be high. If it's exact formula, error is low.
    # For this test, we assume the implementation is accurate.
    
    # Check if result is close
    # Convert result back to float for comparison
    result_float = q16_16_to_float(result_val)
    
    cocotb.log.info(f"Result: {result_val} ({result_float:.5f}), Expected: {expected_fixed} (0.66666)")
    
    if abs(result_float - 0.6666667) > 0.01:
         raise TestFailure(f"Result mismatch. Got {result_float}, expected ~0.66667")
