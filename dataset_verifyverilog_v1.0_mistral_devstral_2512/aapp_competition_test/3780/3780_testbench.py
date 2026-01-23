import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
RESULT_WIDTH = 32  # Q16.16 fixed-point
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
ITERATIONS = 50  # Binary search iterations

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# Fixed-point conversion functions
Q16_16_SCALE = 65536  # 2^16

def float_to_fixed(value):
    """Convert float to Q16.16 fixed-point."""
    return int(value * Q16_16_SCALE)

def fixed_to_float(value):
    """Convert Q16.16 fixed-point to float."""
    # Handle signed values
    if value >= 0x80000000:  # Negative in 32-bit signed
        value = value - 0x100000000
    return value / Q16_16_SCALE

# Reference Python solution for ground truth
def python_solution(x1, y1, x2, y2, v_max, t, vx, vy, wx, wy):
    """Reference implementation using binary search."""
    def check(T):
        t1 = min(t, T)
        t2 = max(T - t, 0)
        wind_x = vx * t1 + wx * t2
        wind_y = vy * t1 + wy * t2
        dx = x2 - x1 - wind_x
        dy = y2 - y1 - wind_y
        return dx*dx + dy*dy <= (v_max * T)**2
    
    lo, hi = 0.0, 1e12
    for _ in range(100):
        mid = (lo + hi) / 2
        if check(mid):
            hi = mid
        else:
            lo = mid
    return hi

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_rescue_rangers(dut):
    """Main test function for rescue_rangers module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from the problem
    test_cases = [
        # (x1, y1, x2, y2, v_max, t, vx, vy, wx, wy, expected_time)
        (0, 0, 5, 5, 3, 2, -1, -1, -1, 0, 3.729935587093555327),
        (0, 0, 0, 1000, 100, 1000, -50, 0, 50, 0, 11.547005383792516398),
        (0, 0, 0, 1000, 100, 5, 0, -50, 0, 50, 10.0),
        (0, 1000, 0, 0, 50, 10, -49, 0, 49, 0, 20.0),
        (0, 1000, 0, 0, 50, 10, 0, -48, 0, -49, 10.202020202020200657),
        (0, 0, 0, -5000, 100, 20, -50, 0, 50, 0, 50.262613427796381416),
        (0, 0, 0, -350, 55, 5, 0, -50, 0, 50, 3.3333333333333330373),
        (0, -1000, 0, 0, 11, 10, -10, 0, 10, 0, 146.8240957550254393),
        (0, -1000, 0, 0, 22, 10, 0, -12, 0, -10, 85.0),
        (0, 7834, -1, 902, 432, 43, 22, 22, -22, -22, 16.930588983107490719),
        (0, -10000, -10000, 0, 1, 777, 0, 0, 0, 0, 14142.13562373095192),
        (0, 0, 0, 750, 25, 30, 0, -1, 0, 24, 30.612244897959186574),
        (-10000, 10000, 10000, 10000, 2, 1000, 0, -1, -1, 0, 19013.151067740152939),
        (-1, -1, 1, 1, 1, 1, 0, 0, 0, 0, 2.8284271247461898469),
        (1, 1, 0, 0, 2, 1, 0, 1, 0, 1, 1.2152504370215302387),
        (-1, -1, 0, 0, 2, 1, -1, 0, 0, -1, 1.1547005383792514621),
        (-1, -1, 1, 1, 2, 1, -1, 0, 0, -1, 2.1892547876100074689),
        (-1, -1, 2, 2, 5, 1, -2, -1, -1, -2, 1.4770329614269006591),
        (-5393, -8779, 7669, 9721, 613, 13, -313, -37, -23, -257, 57.962085855983815463),
        (10000, 10000, -10000, -10000, 1, 999, 0, 0, 0, 0, 28284.27124746190384),
        (10000, -10000, -10000, 10000, 1000, 999, 0, -999, 999, 0, 1018.7770495642339483),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x1, y1, x2, y2, v_max, t, vx, vy, wx, wy, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: ({x1},{y1}) -> ({x2},{y2})")
        
        try:
            # Compute ground truth
            python_time = python_solution(x1, y1, x2, y2, v_max, t, vx, vy, wx, wy)
            
            # Set inputs
            dut.x1.value = clamp_to_width(x1, 16)
            dut.y1.value = clamp_to_width(y1, 16)
            dut.x2.value = clamp_to_width(x2, 16)
            dut.y2.value = clamp_to_width(y2, 16)
            dut.v_max.value = clamp_to_width(v_max, 16)
            dut.t.value = clamp_to_width(t, 16)
            dut.vx.value = clamp_to_width(vx, 16)
            dut.vy.value = clamp_to_width(vy, 16)
            dut.wx.value = clamp_to_width(wx, 16)
            dut.wy.value = clamp_to_width(wy, 16)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.time_result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_fixed = int(dut.time_result.value)
            result_float = fixed_to_float(result_fixed)
            
            # Compare with expected and Python result
            error_abs = abs(result_float - expected)
            error_rel = error_abs / max(1.0, abs(expected))
            
            if error_rel > 1e-6:
                # Also check against Python solution
                python_error = abs(result_float - python_time)
                python_rel = python_error / max(1.0, abs(python_time))
                
                if python_rel > 1e-6:
                    raise TestFailure(
                        f"Result {result_float:.10f} differs from expected {expected:.10f} "
                        f"(rel error {error_rel:.2e}) and Python {python_time:.10f} (rel {python_rel:.2e})"
                    )
            
            cocotb.log.info(f"  PASS: time = {result_float:.10f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
