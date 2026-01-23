import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
    return min(max_val, max(0, value))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_module(dut):
    """Test the square_difference module."""

    # Detect if sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_m, expected_k, expected_valid, description)
    test_cases = [
        (7, 4, 3, 1, 'n=7 odd'),
        (8, 3, 1, 1, 'n=8 divisible by 4'),
        (10, 0, 0, 0, 'n=10 impossible'),
        (12, 4, 2, 1, 'n=12 divisible by 4'),
        (15, 8, 7, 1, 'n=15 odd'),
        (2, 0, 0, 0, 'n=2 impossible'),
        (100, 26, 24, 1, 'n=100 divisible by 4'),
        (1, 1, 0, 1, 'n=1 odd'),
        (4, 2, 0, 1, 'n=4 divisible by 4'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, exp_m, exp_k, exp_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: {desc}')
        
        try:
            # Write input n
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, DATA_WIDTH)
            else:
                raise TestFailure("Signal 'n' not found")
            
            # Wait for combinational propagation
            await Timer(100, units='ns')
            
            # Read outputs
            if not has_signal(dut, 'valid'):
                raise TestFailure("Signal 'valid' not found")
            if not has_signal(dut, 'm'):
                raise TestFailure("Signal 'm' not found")
            if not has_signal(dut, 'k'):
                raise TestFailure("Signal 'k' not found")
            
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal is undefined (X/Z)")
            
            valid = int(dut.valid.value)
            m = int(dut.m.value) if is_value_defined(dut.m.value) else None
            k = int(dut.k.value) if is_value_defined(dut.k.value) else None
            
            # Check valid
            if valid != exp_valid:
                raise TestFailure(f'Valid mismatch: expected {exp_valid}, got {valid}')
            
            # If valid, check m and k
            if exp_valid:
                if m is None or k is None:
                    raise TestFailure('m or k is undefined')
                if m != exp_m:
                    raise TestFailure(f'm mismatch: expected {exp_m}, got {m}')
                if k != exp_k:
                    raise TestFailure(f'k mismatch: expected {exp_k}, got {k}')
            else:
                # For invalid case, we expect m=0, k=0 (as per our design)
                if m is not None and m != 0:
                    cocotb.log.warning(f'Expected m=0 for invalid case, got {m}')
                if k is not None and k != 0:
                    cocotb.log.warning(f'Expected k=0 for invalid case, got {k}')
            
            cocotb.log.info(f'  PASS: valid={valid}, m={m}, k={k}')
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
    
    cocotb.log.info('='*50)
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')
