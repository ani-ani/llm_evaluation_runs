import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 6
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
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
    
    # Try individual ports
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

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

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

# ============================================================================
# PRIME COUNTING FUNCTION (Python reference)
# ============================================================================

def count_primes_below_n(n):
    """Reference implementation for validation."""
    if n <= 2:
        return 0
    count = 0
    for num in range(2, n):
        is_prime = True
        for i in range(2, int(num**0.5) + 1):
            if num % i == 0:
                is_prime = False
                break
        if is_prime:
            count += 1
    return count

# Pre-computed prime counts for N=0 to 64
PRIME_COUNTS = [count_primes_below_n(i) for i in range(65)]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_prime_counter(dut):
    """Main test function for prime counter."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    else:
        # Combinational - wait for initial propagation
        await Timer(100, units='ns')
    
    # Define test cases
    # Format: (input_n, expected_count, description)
    test_cases = [
        (5, 2, "n=5: primes 2,3"),
        (10, 4, "n=10: primes 2,3,5,7"),
        (100, 25, "n=100: primes below 100"),
        # Additional edge cases
        (0, 0, "n=0: edge case"),
        (1, 0, "n=1: edge case"),
        (2, 0, "n=2: no primes <2"),
        (3, 1, "n=3: prime 2 only"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_n, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Clamp input to max supported (64) for designs that may not handle larger values
            clamped_input = min(input_n, 64)
            
            # Write input
            if has_signal(dut, 'n'):
                dut.n.value = clamped_input
            else:
                raise TestFailure("Input signal 'n' not found")
            
            # Wait for propagation
            if is_sequential:
                # For sequential, pulse start if it exists
                if has_signal(dut, 'start'):
                    await start_computation(dut)
                    await wait_for_done(dut)
                else:
                    # Just wait a few cycles
                    for _ in range(5):
                        await RisingEdge(dut.clk)
            else:
                # Combinational - wait for logic to settle
                await Timer(100, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Output signal 'result' not found")
            
            result_signal = dut.result.value
            if not is_value_defined(result_signal):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(result_signal)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(10, units='ns')
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
