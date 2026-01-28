import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Fixed-point constants (Q16.16 format)
CONST_13_12 = 0x000D1F70      # 13.12
CONST_0_6215 = 0x00009E5A     # 0.6215
CONST_11_37 = 0x000B5E85      # 11.37
CONST_0_3965 = 0x0000659F     # 0.3965
HALF_Q16 = 0x00008000         # 0.5 for rounding

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# GOLDEN REFERENCE: Python implementation of wind chill
# ============================================================================

def compute_wind_chill_python(v, t):
    """Compute wind chill in Q16.16 fixed-point, return rounded integer."""
    # Convert to float for calculation
    v_float = float(v)
    t_float = float(t)
    
    # Compute v^0.16
    if v == 0:
        v_pow_016 = 0.0
    else:
        v_pow_016 = v_float ** 0.16
    
    # Apply formula
    windchill = 13.12 + 0.6215*t_float - 11.37*v_pow_016 + 0.3965*t_float*v_pow_016
    
    # Round to nearest integer
    return int(round(windchill, 0))

# Lookup table for v^0.16 (Q16.16 format)
# Computed for v = 0 to 255 (covers our 0-200 range)
V_POW_016_LUT = []
for i in range(256):
    if i == 0:
        V_POW_016_LUT.append(0)
    else:
        val = int((i ** 0.16) * (1 << 16))
        V_POW_016_LUT.append(val)

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_wind_chill(dut):
    """Test wind chill calculator with multiple test cases."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset sequence
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        
        for _ in range(3):
            await RisingEdge(dut.clk)
        
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (wind_kmh, temp_c, expected_windchill)
    test_cases = [
        (120, 35, 40),  # High wind, hot day
        (40, 20, 19),   # Moderate wind, warm day
        (10, 8, 6),     # Low wind, cool day
        (0, 10, 10),    # No wind
        (200, -20, -43), # Very high wind, cold day
        (50, 0, -3),    # Standard case
    ]
    
    passed = 0
    failed = 0
    
    for i, (wind, temp, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: wind={wind} km/h, temp={temp}°C, expected={expected}")
        
        try:
            # Write inputs
            # Temperature is signed 16-bit
            dut.temp_in.value = from_signed(temp, 16)
            # Wind is unsigned 16-bit
            dut.wind_in.value = wind
            
            if is_sequential:
                # Pulse start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done with timeout
                done_timeout = 0
                while done_timeout < MAX_CYCLES:
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                    done_timeout += 1
                else:
                    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result_raw = int(dut.result.value)
            result = to_signed(result_raw, 16)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")