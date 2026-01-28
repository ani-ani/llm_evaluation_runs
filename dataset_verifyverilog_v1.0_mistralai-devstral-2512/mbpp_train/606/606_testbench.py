import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for fixed-point arithmetic
PI_Q16_16 = 0x3243F6A8  # 3.141592653589793
INV_180_Q16_16 = 0x0002E14F  # 1/180 = 0.005555555555556
DATA_WIDTH = 16
RESULT_WIDTH = 32
CLK_NS = 10

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    # Handle signed 32-bit
    if v & (1 << 31):
        v = v - (1 << 32)
    return v / (1 << frac)

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_degrees_to_radians(dut):
    # Setup clock and reset
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (degrees, expected_radians)
    test_cases = [
        (90, 1.5707963267948966),
        (60, 1.0471975511965976),
        (120, 2.0943951023931953),
    ]
    
    for deg, expected_rad in test_cases:
        # Convert degree to Q8.8 fixed-point
        deg_fixed = int(deg * (1 << 8))
        deg_signed = to_signed(deg_fixed, 16) & 0xFFFF
        
        # Input
        dut.degree_in.value = deg_signed
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (3 cycles from start)
        for _ in range(3):
            await RisingEdge(dut.clk)
        
        # Check done signal
        if not is_value_defined(dut.done.value):
            raise TestFailure(f"Done signal undefined for {deg} degrees")
        
        done_val = int(dut.done.value)
        if done_val != 1:
            raise TestFailure(f"Expected done=1, got {done_val} for {deg} degrees")
        
        # Read result
        if not is_value_defined(dut.radian_out.value):
            raise TestFailure(f"Result undefined for {deg} degrees")
        
        result = int(dut.radian_out.value)
        result_float = fixed_to_float(result, 16)
        
        # Allow small tolerance due to fixed-point precision
        tolerance = 0.0001
        if abs(result_float - expected_rad) > tolerance:
            raise TestFailure(
                f"Deg {deg}: Expected {expected_rad:.6f}, got {result_float:.6f} "
                f"(diff={abs(result_float - expected_rad):.6f})"
            )
        
        cocotb.log.info(f"Test passed: {deg}° -> {result_float:.6f} rad (expected {expected_rad:.6f})")
    
    # Additional test: 0 degrees
    deg = 0
    deg_fixed = int(deg * (1 << 8))
    deg_signed = to_signed(deg_fixed, 16) & 0xFFFF
    dut.degree_in.value = deg_signed
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    result = int(dut.radian_out.value)
    result_float = fixed_to_float(result, 16)
    if abs(result_float) > 0.0001:
        raise TestFailure(f"0 degrees should yield ~0 radians, got {result_float}")
    cocotb.log.info("Zero-degree test passed")
    
    # Additional test: 180 degrees
    deg = 180
    expected_rad = math.pi
    deg_fixed = int(deg * (1 << 8))
    deg_signed = to_signed(deg_fixed, 16) & 0xFFFF
    dut.degree_in.value = deg_signed
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    result = int(dut.radian_out.value)
    result_float = fixed_to_float(result, 16)
    if abs(result_float - expected_rad) > 0.0001:
        raise TestFailure(f"180 degrees should yield π radians, got {result_float}")
    cocotb.log.info("180-degree test passed")
