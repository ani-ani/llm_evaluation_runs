import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
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
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_polyline_solver(dut):
    """Main test function for polyline_solver module."""
    
    # Detect if module is sequential (has clk and done signals)
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset (active-low)
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
        else:
            # No reset, just wait for first clock edge
            await RisingEdge(dut.clk)
    
    # Define test cases: (a, b, expected_output)
    # expected_output is either a float (for valid solutions) or -1 (for no solution)
    test_cases = [
        (3, 1, 1.0),
        (1, 3, -1),
        (4, 1, 1.25),
        (1000000000, 1000000000, 1000000000.0),
        (1000000000, 1, 1.000000001),
        (991691248, 43166756, 47039000.18181818),
        (973970808, 679365826, 826668317.0),
        (404878182, 80324806, 80867164.666666672),
        (405262931, 391908625, 398585778.0),
        (758323881, 37209930, 39776690.549999997),
        (405647680, 36668977, 36859721.416666664),
        (750322953, 61458580, 67648461.083333328),
        (406032429, 31993512, 36502161.75),
        (1000000000, 111111111, 111111111.09999999),
        (999999999, 111111111, 111111111.0),
        (999999998, 111111111, 138888888.625),
        (888888888, 111111111, 124999999.875),
        (1, 1000000000, -1),
        (999899988, 13, 13.000000117012),
        (481485937, 21902154, 22881276.863636363),
        (836218485, 1720897, 1724155.1069958848),
        (861651807, 2239668, 2249717.3828125),
        (829050416, 2523498, 2535286.3231707318),
        (1000000000, 999999999, 999999999.5),
        (999999999, 1000000000, -1),
        (11, 5, 8.0),
        (100000000, 1, 1.00000001),
        (1488, 1, 1.000672043011),
        (11, 3, 3.5),
        (30, 5, 5.833333333333),
        (5, 1, 1.0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: a={a}, b={b}, expected={expected}")
        
        try:
            # Set inputs
            dut.a.value = a
            dut.b.value = b
            
            if is_sequential:
                # Wait for computation (sequential)
                # Pulse start if exists, else just wait for done
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                
                # Wait for done with timeout
                cycles = 0
                while cycles < MAX_CYCLES:
                    await RisingEdge(dut.clk)
                    cycles += 1
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read outputs
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal is undefined (X/Z)")
            
            valid = int(dut.valid.value)
            num = int(dut.num.value) if is_value_defined(dut.num.value) else 0
            den = int(dut.den.value) if is_value_defined(dut.den.value) else 1
            
            # Verify
            if expected == -1:
                if valid != 0:
                    raise TestFailure(f"Expected invalid (valid=0), got valid={valid}")
            else:
                if valid != 1:
                    raise TestFailure(f"Expected valid=1, got valid={valid}")
                
                if den == 0:
                    raise TestFailure("Denominator is zero")
                
                result = num / den
                # Allow tolerance of 1e-9 absolute or relative
                if abs(result - expected) > 1e-9:
                    raise TestFailure(f"Result mismatch: expected {expected}, got {result} (num={num}, den={den})")
            
            dut._log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
