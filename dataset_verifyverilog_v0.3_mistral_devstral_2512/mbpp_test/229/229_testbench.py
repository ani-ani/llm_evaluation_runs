import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8  # 8-bit signed values (-128 to 127)
ARRAY_SIZE = 8  # Maximum array elements
RESULT_WIDTH = 8
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

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

def python_rearrange(arr, n):
    """Python reference implementation."""
    arr_copy = arr[:n]
    j = 0
    for i in range(n):
        if arr_copy[i] < 0:
            arr_copy[i], arr_copy[j] = arr_copy[j], arr_copy[i]
            j += 1
    return arr_copy

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_rearrange_array(dut):
    """Test rearrange array module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        # (input_array, n, expected_output, description)
        ([-1, 2, -3, 4, 5, 6, -7, 8, 9], 9, [-1, -3, -7, 4, 5, 6, 2, 8, 9], "Mixed negatives and positives"),
        ([-14, -26, 12, 13, 15], 5, [-14, -26, 12, 13, 15], "Two negatives then positives"),
        ([10, 24, 36, -42, -39, -78, 85], 7, [-42, -39, -78, 10, 24, 36, 85], "Positives then negatives"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, [1, 2, 3, 4, 5, 6, 7, 8], "All positives"),
        ([-1, -2, -3, -4, -5, -6, -7, -8], 8, [-1, -2, -3, -4, -5, -6, -7, -8], "All negatives"),
        ([0, 1, -1, 2, -2, 3], 6, [0, -1, -2, 1, 2, 3], "With zeros"),
        ([5], 1, [5], "Single positive"),
        ([-5], 1, [-5], "Single negative"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (input_arr, n, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: {description}")
        cocotb.log.info(f"  Input: {input_arr[:n]}, n={n}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Ensure we only send n elements (pad with zeros)
            input_padded = input_arr[:ARRAY_SIZE]
            if len(input_padded) < ARRAY_SIZE:
                input_padded.extend([0] * (ARRAY_SIZE - len(input_padded)))
            
            # Write inputs
            await write_array(dut, 'arr', input_padded, DATA_WIDTH)
            dut.n.value = n
            
            if is_sequential:
                # Start computation
                await start_computation(dut)
                
                # Wait for done
                await wait_for_done(dut)
                
                # Verify valid signal if exists
                if has_signal(dut, 'valid'):
                    valid_val = int(dut.valid.value)
                    if valid_val != n:
                        raise TestFailure(f"Valid signal {valid_val} != n {n}")
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result array
            result = read_array(dut, 'result', n)
            
            # Convert from signed representation if needed
            result_signed = []
            for r in result:
                if r is None:
                    raise TestFailure(f"Result element is undefined (X/Z)")
                result_signed.append(to_signed(r, DATA_WIDTH))
            
            # Compare with expected
            if result_signed != expected:
                raise TestFailure(f"Result mismatch: got {result_signed}, expected {expected}")
            
            cocotb.log.info(f"  PASS: Result = {result_signed}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        if is_sequential:
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
