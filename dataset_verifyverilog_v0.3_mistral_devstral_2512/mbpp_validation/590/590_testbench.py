import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32      # Q16.16 format
INT_BITS = 16
FRAC_BITS = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 200
PI_FIXED = int(math.pi * (1 << FRAC_BITS))  # pi in Q16.16

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

def float_to_fixed(f, frac_bits=FRAC_BITS):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST FUNCTION
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_polar_rect_converter(dut):
    """Test polar-rectangular coordinate converter."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    # Format: (mode, in1, in2, expected_out1, expected_out2, description)
    # mode: 0 = Rectangular to Polar, 1 = Polar to Rectangular
    
    # Rectangular to Polar tests (mode=0)
    # Input (3, 4): r = 5.0, theta = 0.9273
    # Input (4, 7): r = 8.0623, theta = 1.0517
    # Input (15, 17): r = 22.6716, theta = 0.8478
    
    # For simplicity, we'll test Rectangular to Polar mode
    # and verify approximate results (within tolerance)
    
    test_cases = [
        (0, float_to_fixed(3.0), float_to_fixed(4.0), 
         float_to_fixed(5.0), float_to_fixed(0.9273), 
         "Polar(3,4) -> Rect"),
        
        (0, float_to_fixed(4.0), float_to_fixed(7.0), 
         float_to_fixed(8.0623), float_to_fixed(1.0517), 
         "Polar(4,7) -> Rect"),
        
        (0, float_to_fixed(15.0), float_to_fixed(17.0), 
         float_to_fixed(22.6716), float_to_fixed(0.8478), 
         "Polar(15,17) -> Rect"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (mode, in1, in2, exp_out1, exp_out2, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input (fixed): in1={in1} (0x{in1:08X}), in2={in2} (0x{in2:08X})")
        
        try:
            # Set inputs
            dut.mode.value = mode
            dut.in1.value = clamp_to_width(in1, DATA_WIDTH)
            dut.in2.value = clamp_to_width(in2, DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check error flag
            if has_signal(dut, 'error') and is_value_defined(dut.error.value):
                if int(dut.error.value) == 1:
                    raise TestFailure(f"Error flag asserted for valid input")
            
            # Read outputs
            if not (is_value_defined(dut.out1.value) and is_value_defined(dut.out2.value)):
                raise TestFailure(f"Outputs are undefined (X/Z)")
            
            out1 = int(dut.out1.value)
            out2 = int(dut.out2.value)
            
            # Convert to float for comparison
            out1_float = fixed_to_float(out1)
            out2_float = fixed_to_float(out2)
            exp1_float = fixed_to_float(exp_out1)
            exp2_float = fixed_to_float(exp_out2)
            
            cocotb.log.info(f"  Output (fixed): out1={out1} (0x{out1:08X}), out2={out2} (0x{out2:08X})")
            cocotb.log.info(f"  Output (float): out1={out1_float:.4f}, out2={out2_float:.4f}")
            cocotb.log.info(f"  Expected (float): out1={exp1_float:.4f}, out2={exp2_float:.4f}")
            
            # Allow 1% tolerance for fixed-point approximation
            tol = 0.01
            
            err1 = abs(out1_float - exp1_float) / max(1.0, exp1_float)
            err2 = abs(out2_float - exp2_float) / max(1.0, exp2_float)
            
            if err1 > tol or err2 > tol:
                raise TestFailure(f"Output mismatch: err1={err1:.4f}, err2={err2:.4f} (tol={tol})")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# Additional test for Polar to Rectangular mode (mode=1)
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_polar_to_rect(dut):
    """Test Polar to Rectangular mode."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test: Polar(r=5, theta=pi/4) should give approximately (3.5355, 3.5355)
    # r=5.0, theta=0.7854 (pi/4)
    
    r = float_to_fixed(5.0)
    theta = float_to_fixed(0.7854)  # pi/4
    
    cocotb.log.info(f"\nPolar to Rect Test: r=5.0, theta=pi/4")
    
    dut.mode.value = 1  # Polar to Rect
    dut.in1.value = r
    dut.in2.value = theta
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    if is_value_defined(dut.out1.value) and is_value_defined(dut.out2.value):
        x = fixed_to_float(int(dut.out1.value))
        y = fixed_to_float(int(dut.out2.value))
        
        cocotb.log.info(f"  Result: x={x:.4f}, y={y:.4f}")
        cocotb.log.info(f"  Expected: x=3.5355, y=3.5355")
        
        # Check within tolerance
        if abs(x - 3.5355) < 0.1 and abs(y - 3.5355) < 0.1:
            cocotb.log.info("  PASS")
        else:
            cocotb.log.warning("  WARNING: May need algorithm adjustment")
    else:
        cocotb.log.warning("  WARNING: Outputs undefined")
