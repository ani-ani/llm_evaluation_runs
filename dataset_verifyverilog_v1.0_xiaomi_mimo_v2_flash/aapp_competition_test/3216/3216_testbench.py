import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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
# HELPER FUNCTIONS FOR THIS TESTBENCH
# ============================================================================

def pack_fractional_digits(frac_str):
    """Pack fractional digits string into 44-bit integer, 4 bits per digit, MSB first."""
    packed = 0
    for i, ch in enumerate(frac_str):
        digit = int(ch)
        shift = 4 * (10 - i)   # digit i goes to bits [43-4*i : 40-4*i]
        packed |= (digit << shift)
    return packed

def compute_expected(decimal_str, repeat_count):
    """Compute expected numerator and denominator (unreduced) for the given input."""
    int_str, frac_str = decimal_str.split('.')
    integer_part = int(int_str)
    L = len(frac_str)
    R = repeat_count
    K = L - R

    A_str = frac_str[:K] if K > 0 else ""
    B_str = frac_str[K:]  # length R
    A = int(A_str) if K > 0 else 0
    B = int(B_str)

    pow10_R = 10 ** R
    pow10_K = 10 ** K

    denominator = pow10_K * (pow10_R - 1)
    numerator = integer_part * denominator + (A * pow10_R + B - A)

    return numerator, denominator

def reduce_fraction(num, den):
    """Reduce fraction by dividing by GCD."""
    g = math.gcd(num, den)
    return num // g, den // g

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rational_to_fraction(dut):
    """Test rational to fraction conversion."""
    
    # Detect if DUT has clock and done (sequential module)
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock (10 ns period)
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
        # Reset sequence
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational module - just wait for propagation
        await Timer(100, units='ns')
    
    # Test cases: (input_line, expected_output_line)
    test_cases = [
        ("0.142857 6", "1/7"),
        ("1.6 1", "5/3"),
        ("123.456 2", "61111/495"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_line, expected_output) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {input_line} -> {expected_output}")
        
        try:
            # Parse input
            parts = input_line.split()
            decimal_str = parts[0]
            repeat_count = int(parts[1])
            
            # Compute expected unreduced numerator/denominator
            expected_num, expected_den = compute_expected(decimal_str, repeat_count)
            
            # Prepare DUT inputs
            int_str, frac_str = decimal_str.split('.')
            integer_part = int(int_str)
            L = len(frac_str)
            R = repeat_count
            
            # Pack fractional digits
            digits_packed = pack_fractional_digits(frac_str)
            
            # Drive DUT inputs
            if has_signal(dut, 'integer_part'):
                dut.integer_part.value = clamp_to_width(integer_part, 10)
            if has_signal(dut, 'digits_packed'):
                dut.digits_packed.value = clamp_to_width(digits_packed, 44)
            if has_signal(dut, 'L'):
                dut.L.value = clamp_to_width(L, 4)
            if has_signal(dut, 'R'):
                dut.R.value = clamp_to_width(R, 4)
            
            # Start computation
            if is_sequential:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                for _ in range(1000):  # timeout after 1000 cycles
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure("Timeout waiting for done")
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read outputs
            if not is_value_defined(dut.numerator.value) or not is_value_defined(dut.denominator.value):
                raise TestFailure("Output signals undefined (X/Z)")
            
            actual_num = int(dut.numerator.value)
            actual_den = int(dut.denominator.value)
            
            # Compare with expected unreduced fraction
            if actual_num != expected_num or actual_den != expected_den:
                # Also check reduced form
                reduced_actual_num, reduced_actual_den = reduce_fraction(actual_num, actual_den)
                reduced_expected_num, reduced_expected_den = reduce_fraction(expected_num, expected_den)
                
                if (reduced_actual_num != reduced_expected_num) or (reduced_actual_den != reduced_expected_den):
                    raise TestFailure(
                        f"Unreduced mismatch: got {actual_num}/{actual_den}, expected {expected_num}/{expected_den}. "
                        f"Reduced: got {reduced_actual_num}/{reduced_actual_den}, expected {reduced_expected_num}/{reduced_expected_den}"
                    )
            
            # Verify reduced form matches expected output
            reduced_actual_num, reduced_actual_den = reduce_fraction(actual_num, actual_den)
            expected_reduced_num, expected_reduced_den = map(int, expected_output.split('/'))
            if reduced_actual_num != expected_reduced_num or reduced_actual_den != expected_reduced_den:
                raise TestFailure(
                    f"Reduced fraction mismatch: got {reduced_actual_num}/{reduced_actual_den}, expected {expected_reduced_num}/{expected_reduced_den}"
                )
            
            dut._log.info(f"  PASS: {actual_num}/{actual_den} -> {reduced_actual_num}/{reduced_actual_den}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")