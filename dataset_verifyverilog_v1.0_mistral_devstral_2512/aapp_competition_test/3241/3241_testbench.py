import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_ham_distribution(dut):
    """Test ham distribution module."""
    
    # Detect if sequential module
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
        # Reset if present
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
        else:
            await RisingEdge(dut.clk)
    else:
        # Combinational - wait for propagation
        await Timer(100, units='ns')
    
    # Define test cases: (A0,A1,A2, B0,B1,B2, expected_result, description)
    test_cases = [
        (0, 5, 0, 2, 1, 0, 15.0, "Simple lower bound"),
        (0, 5, 1, 4, 1, 2, 20.0, "Both bounds"),
        (0, 5, 0, 1, 2, 0, -1.0, "No solution"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a0, a1, a2, b0, b1, b2, expected, desc) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        try:
            # Write inputs
            if has_signal(dut, 'A0'):
                dut.A0.value = a0
                dut.A1.value = a1
                dut.A2.value = a2
                dut.B0.value = b0
                dut.B1.value = b1
                dut.B2.value = b2
            else:
                raise TestFailure("Input signals A0..A2, B0..B2 not found")
            
            # Wait for computation
            if is_sequential:
                await RisingEdge(dut.clk)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            result_val = dut.result.value
            if result_val is None:
                raise TestFailure("Result is None")
            
            # Result is real; convert to float
            result_float = float(result_val)
            
            # Compare with expected
            if expected < 0:
                # Expect -1.0
                if abs(result_float - (-1.0)) < 1e-9:
                    dut._log.info(f"  PASS: got -1.0")
                    passed += 1
                else:
                    raise TestFailure(f"Expected -1.0, got {result_float}")
            else:
                # Allow small error due to floating-point
                if abs(result_float - expected) < 1e-6:
                    dut._log.info(f"  PASS: got {result_float}")
                    passed += 1
                else:
                    raise TestFailure(f"Expected {expected}, got {result_float}")
        
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
