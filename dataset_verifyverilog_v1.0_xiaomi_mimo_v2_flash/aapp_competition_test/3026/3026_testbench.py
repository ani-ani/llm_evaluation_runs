import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 16
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_critical_elements(dut):
    """Main test function."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (sequence, expected_critical_values, description)
    test_cases = [
        ([1, 3, 2, 4], [1, 4], "Sample 1: n=4"),
        ([1, 2, 3, 4, 5], [1, 2, 3, 4, 5], "Sample 2: n=5"),
        ([2, 1, 4, 3], [], "Sample 3: no critical"),
        ([4, 3, 1, 2], [1, 2], "Sample 4: n=4"),
        ([1, 4, 2, 3], [1, 4], "Additional test 1"),
        ([3, 1, 2, 4], [1, 4], "Additional test 2"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (sequence, expected_critical, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input sequence: {sequence}")
        cocotb.log.info(f"  Expected critical: {expected_critical}")
        
        try:
            # Set n and write sequence
            n = len(sequence)
            dut.n.value = n
            
            # Write sequence to arr
            for j in range(n):
                dut.arr[j].value = sequence[j]
            
            # Fill remaining arr elements with 0 (not used)
            for j in range(n, ARRAY_SIZE):
                dut.arr[j].value = 0
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read critical count
            if not is_value_defined(dut.critical_count.value):
                raise TestFailure("critical_count is undefined")
            
            critical_count = int(dut.critical_count.value)
            
            # Read critical array
            critical_values = []
            for j in range(critical_count):
                if is_value_defined(dut.critical[j].value):
                    critical_values.append(int(dut.critical[j].value))
                else:
                    critical_values.append(None)
            
            # Sort expected for comparison (they should already be sorted from hardware)
            expected_sorted = sorted(expected_critical)
            
            # Check if critical_count matches
            if critical_count != len(expected_sorted):
                raise TestFailure(f"Critical count mismatch: expected {len(expected_sorted)}, got {critical_count}")
            
            # Check each critical value
            for j in range(critical_count):
                if critical_values[j] != expected_sorted[j]:
                    raise TestFailure(f"Critical[{j}] mismatch: expected {expected_sorted[j]}, got {critical_values[j]}")
            
            cocotb.log.info(f"  PASS: critical values = {critical_values}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")