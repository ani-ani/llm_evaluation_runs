import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helpers
DATA_WIDTH = 32
FRAC_BITS = 16
MAX_VAL = (1 << DATA_WIDTH) - 1

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    # Handle negative numbers for signed clamping
    max_val = (1 << (bits - 1)) - 1
    min_val = -(1 << (bits - 1))
    if v > max_val: return max_val
    if v < min_val: return min_val
    return v

def float_to_fixed(f, frac=FRAC_BITS):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=FRAC_BITS):
    if v & (1 << (DATA_WIDTH - 1)): # Negative check for 32-bit
        v = v - (1 << DATA_WIDTH)
    return v / (1 << frac)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_cut(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Data (Scaled to fit range [-1000, 1000])
    # Case 1: Square A, Quad B. Expected ~40.0
    # Scaled: Divide coords by 1000
    A1 = [(0,0), (0,14), (15,14), (15,0)]
    B1 = [(8,3), (4,6), (7,10), (11,7)]
    
    # Case 2: Square A, Octagon B. Expected ~322.14
    # A: 400x400, B: center 0, radius ~1.41
    A2 = [(-100,-100), (-100,100), (100,100), (100,-100)]
    B2 = [(-1,-2), (-2,-1), (-2,1), (-1,2), (1,2), (2,1), (2,-1), (1,-2)]
    
    # Scale factor to keep within 16.16 range
    scale = 0.001 # Scaling input down
    
    test_sets = [
        (A1, B1, 40.0),
        (A2, B2, 322.1421356237)
    ]

    for t_idx, (poly_a, poly_b, expected_cost) in enumerate(test_sets):
        dut._log.info(f"Running Test Case {t_idx + 1}")
        
        # Load Polygon A
        if has_signal(dut, 'a_x') and has_signal(dut, 'a_y'):
            # If it's a serial load interface
            dut.a_valid.value = 1
            for x, y in poly_a:
                dut.a_x.value = clamp_to_width(float_to_fixed(x * scale), 32)
                dut.a_y.value = clamp_to_width(float_to_fixed(y * scale), 32)
                await RisingEdge(dut.clk)
            dut.a_valid.value = 0
        elif has_signal(dut, 'a_arr_x'):
            # If it's parallel array interface
            for i, (x, y) in enumerate(poly_a):
                getattr(dut, f'a_arr_x_{i}').value = clamp_to_width(float_to_fixed(x * scale), 32)
                getattr(dut, f'a_arr_y_{i}').value = clamp_to_width(float_to_fixed(y * scale), 32)
        
        # Load Polygon B
        if has_signal(dut, 'b_x') and has_signal(dut, 'b_y'):
            dut.b_valid.value = 1
            for x, y in poly_b:
                dut.b_x.value = clamp_to_width(float_to_fixed(x * scale), 32)
                dut.b_y.value = clamp_to_width(float_to_fixed(y * scale), 32)
                await RisingEdge(dut.clk)
            dut.b_valid.value = 0
        elif has_signal(dut, 'b_arr_x'):
            for i, (x, y) in enumerate(poly_b):
                getattr(dut, f'b_arr_x_{i}').value = clamp_to_width(float_to_fixed(x * scale), 32)
                getattr(dut, f'b_arr_y_{i}').value = clamp_to_width(float_to_fixed(y * scale), 32)

        # Start Calculation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 5000
        done = False
        for _ in range(max_cycles):
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
            await RisingEdge(dut.clk)
        
        if not done:
            raise TestFailure(f"Test {t_idx+1}: Timeout waiting for done signal")
        
        # Read Result
        if has_signal(dut, 'result'):
            res_val = int(dut.result.value)
            # Handle 64-bit result if present, or 32-bit
            # Assuming result is 64-bit fixed point (32.32) or scaled 32.16
            # The module should output a scaled integer.
            # We need to convert back to float. 
            # Assuming 32-bit result for simplicity in this template, or check width
            
            # Check bit width of result signal
            result_bits = len(dut.result)
            if result_bits > 32:
                 # Likely 64 bit, assume 32.16 or 32.32 scaling
                 # Let's assume the module output is scaled by 2^16 for fixed point
                 # Or we handle 64-bit int
                 actual = to_signed(res_val, result_bits) / (1 << 16) # Assuming Q16.16 output
            else:
                 actual = to_signed(res_val, 32) / (1 << 16)
            
            dut._log.info(f"Test {t_idx+1}: Result {actual}, Expected {expected_cost}")
            
            if abs(actual - expected_cost) > expected_cost * 0.0001:
                raise TestFailure(f"Test {t_idx+1}: Result mismatch. Got {actual}, Expected {expected_cost}")
        else:
            raise TestFailure("Result signal not found")
            
    dut._log.info("All tests passed")