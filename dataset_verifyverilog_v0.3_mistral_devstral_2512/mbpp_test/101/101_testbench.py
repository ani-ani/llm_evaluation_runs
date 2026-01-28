import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
K_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY WRITE/READ HELPERS
# ============================================================================

async def write_array_to_ports(dut, values, element_width=DATA_WIDTH):
    """Write values to individual arr_0, arr_1, ... arr_7 ports."""
    for i in range(8):
        port_name = f"arr_{i}"
        if has_signal(dut, port_name):
            if i < len(values):
                getattr(dut, port_name).value = clamp_to_width(values[i], element_width)
            else:
                getattr(dut, port_name).value = 0
        else:
            raise TestFailure(f"Port {port_name} not found")

async def reset_dut(dut, cycles=2):
    """Standard reset sequence for active-low reset."""
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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_kth_element(dut):
    """Test kth element finder with bubble sort implementation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (array, k, expected)
    test_cases = [
        ([12, 3, 5, 7, 19], 2, 3),
        ([17, 24, 8, 23], 3, 8),
        ([16, 21, 25, 36, 4], 4, 36),
        ([1, 2, 3, 4, 5], 1, 1),  # Edge case: k=1
        ([5, 4, 3, 2, 1], 5, 5),  # Edge case: k=n
        ([10], 1, 10),            # Single element
        ([7, 7, 7, 7], 3, 7),     # All equal elements
        ([255, 0, 128, 64], 2, 64),  # Full range values
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, k, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: arr={arr}, k={k}, expected={expected}")
        
        try:
            # Determine array size
            array_size = len(arr)
            
            # Write array to individual ports
            await write_array_to_ports(dut, arr, DATA_WIDTH)
            
            # Write k and array_size
            dut.k.value = clamp_to_width(k, K_WIDTH)
            dut.array_size.value = clamp_to_width(array_size, K_WIDTH)
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
            # Wait one more cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
