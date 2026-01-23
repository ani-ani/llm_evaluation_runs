import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 12      # For a and b coefficients
T_WIDTH = 8          # For t coefficient
TIME_WIDTH = 7       # For T (0-127)
MAX_TIME = 127
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_roller_coaster(dut):
    """Test the roller coaster optimization module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(2 * CLK_PERIOD_NS, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Define test cases
    # Format: (N, [(a,b,t)], T, expected, description)
    test_cases = [
        # Test case 1: b=0 (constant fun)
        (2, [(5, 0, 5), (7, 0, 7)], 88, 88, "88 min, optimal mix"),
        (2, [(5, 0, 5), (7, 0, 7)], 5, 5, "5 min, ride coaster 0"),
        (2, [(5, 0, 5), (7, 0, 7)], 6, 5, "6 min, ride coaster 0"),
        (2, [(5, 0, 5), (7, 0, 7)], 7, 7, "7 min, ride coaster 1"),
        
        # Test case 2: b>0 (decreasing fun)
        (1, [(100, 3, 2)], 2, 100, "Ride once"),
        (1, [(100, 3, 2)], 3, 100, "Ride once (no time for second)"),
        (1, [(100, 3, 2)], 4, 197, "Ride twice"),
        (1, [(100, 3, 2)], 5, 197, "Ride twice (no time for third)"),
        (1, [(100, 3, 2)], 100, 435, "Multiple rides"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (N, coeffs, T, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {description}")
        
        try:
            if is_sequential:
                # Reset between tests
                dut.rst_n.value = 0
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                dut.rst_n.value = 1
                await RisingEdge(dut.clk)
            
            # Pack coefficients into 32-bit values
            # Format: {a[11:0], b[11:0], t[7:0]}
            coeff_values = []
            for a, b, t in coeffs:
                a_val = clamp_to_width(a, DATA_WIDTH)
                b_val = clamp_to_width(b, DATA_WIDTH)
                t_val = clamp_to_width(t, T_WIDTH)
                packed = (a_val << 20) | (b_val << 8) | t_val
                coeff_values.append(packed)
            
            # Pad to 4 coasters
            while len(coeff_values) < 4:
                coeff_values.append(0)
            
            # Assign to ports
            dut.coeff0.value = coeff_values[0]
            dut.coeff1.value = coeff_values[1]
            dut.coeff2.value = coeff_values[2]
            dut.coeff3.value = coeff_values[3]
            dut.N.value = clamp_to_width(N, 2)  # 2 bits for 0-3
            dut.T.value = clamp_to_width(T, TIME_WIDTH)
            
            # Wait for signals to settle
            await Timer(10, units='ns')
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            if is_sequential:
                if has_signal(dut, 'done'):
                    cycles = 0
                    while cycles < MAX_CYCLES:
                        await RisingEdge(dut.clk)
                        cycles += 1
                        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                            break
                    else:
                        raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                else:
                    await Timer(100, units='ns')
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
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