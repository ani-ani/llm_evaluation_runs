import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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
    return min((1 << bits) - 1, max(0, v))

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Constants
CLK_NS = 10
MAX_CYCLES = 500
TIMEOUT_MS = 1000

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_pills(dut, pills_data, pill_count):
    """Write pill data to individual input ports"""
    for i in range(min(pill_count, 8)):
        t, x, y = pills_data[i]
        # Scale inputs: t by 1024, x and y by 8
        t_scaled = clamp_to_width(int(t * 16), 32)  # Q16.16
        x_scaled = clamp_to_width(int(x * 8), 8)
        y_scaled = clamp_to_width(int(y * 8), 8)
        
        getattr(dut, f'pill_t_{i}').value = t_scaled
        getattr(dut, f'pill_x_{i}').value = x_scaled
        getattr(dut, f'pill_y_{i}').value = y_scaled

@cocotb.test(timeout_time=TIMEOUT_MS, timeout_unit="ms")
async def test_pills(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases: (n_scaled, c_scaled, pills, expected_result, description)
    test_cases = [
        # Case 1: Sample from problem (n=100, c=10, 3 pills)
        # Scaled: n=100/1024≈0.0977, c=10/1024≈0.0098
        (98, 10, [(15744, 1238, 1224), (40960, 24, 16), (92160, 80, 72)], 115.0, "Original sample"),
        # Case 2: Single pill
        (98, 10, [(15744, 1238, 1224)], 100.0, "Single pill (no benefit)"),
        # Case 3: No pills (p=0)
        (98, 10, [], 100.0, "No pills"),
        # Case 4: Two beneficial pills
        (98, 10, [(15744, 24, 16), (40960, 80, 72)], 115.0, "Two pills"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_scaled, c_scaled, pills, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            if is_seq:
                # Set inputs
                dut.n_scaled.value = n_scaled
                dut.c_scaled.value = c_scaled
                dut.pill_count.value = len(pills)
                
                # Write pill data
                for pill_idx, (t, x, y) in enumerate(pills):
                    if pill_idx < 8:
                        getattr(dut, f'pill_t_{pill_idx}').value = t
                        getattr(dut, f'pill_x_{pill_idx}').value = x
                        getattr(dut, f'pill_y_{pill_idx}').value = y
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=MAX_CYCLES)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                    
                result_raw = int(dut.result.value)
                result_float = fixed_to_float(result_raw, 16)
            else:
                # Combinational
                dut.n_scaled.value = n_scaled
                dut.c_scaled.value = c_scaled
                dut.pill_count.value = len(pills)
                
                for pill_idx, (t, x, y) in enumerate(pills):
                    if pill_idx < 8:
                        getattr(dut, f'pill_t_{pill_idx}').value = t
                        getattr(dut, f'pill_x_{pill_idx}').value = x
                        getattr(dut, f'pill_y_{pill_idx}').value = y
                
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                    
                result_raw = int(dut.result.value)
                result_float = fixed_to_float(result_raw, 16)
            
            # Compare with expected (allow small error due to scaling)
            if abs(result_float - expected) > 1.0:  # 1 second tolerance
                raise TestFailure(f"Expected {expected:.3f}, got {result_float:.3f}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Got {result_float:.3f}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{passed}")
