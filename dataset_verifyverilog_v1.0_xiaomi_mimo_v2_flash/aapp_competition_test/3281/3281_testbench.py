import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
FRAC_BITS = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def float_to_fixed(f, frac_bits=FRAC_BITS):
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    return fixed / (1 << frac_bits)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_elisabeth_path(dut):
    """Test the Elisabeth path finding module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (D_value, expected_output_type, expected_angle)
    # For "Impossible", expected_angle is None
    test_cases = [
        (500.0, "angle", 90.0),        # Sample 1
        (450.0, "angle", 126.86989765), # Sample 2
        (440.0, "impossible", None),    # Sample 3
    ]
    
    passed = 0
    failed = 0
    
    for i, (d_val, out_type, expected_angle) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: D={d_val}, Expected: {out_type}")
        
        try:
            # Convert D to fixed-point
            d_fixed = float_to_fixed(d_val)
            dut.D.value = d_fixed
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_raw = int(dut.result.value)
            
            if out_type == "impossible":
                if result_raw != 0xFFFFFFFF:
                    raise TestFailure(f"Expected 'Impossible' (0xFFFFFFFF), got {result_raw:#x}")
                cocotb.log.info(f"  PASS: Correctly output 'Impossible'")
            else:
                if result_raw == 0xFFFFFFFF:
                    raise TestFailure("Expected angle, got 'Impossible'")
                
                result_angle = fixed_to_float(result_raw)
                # Allow small error
                if abs(result_angle - expected_angle) > 1e-6:
                    raise TestFailure(f"Expected {expected_angle}, got {result_angle}")
                
                cocotb.log.info(f"  PASS: angle = {result_angle:.8f}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
