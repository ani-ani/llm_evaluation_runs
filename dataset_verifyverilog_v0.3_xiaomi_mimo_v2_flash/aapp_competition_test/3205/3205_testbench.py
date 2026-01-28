import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 10  # receipt_p width
MAX_PEOPLE = 8
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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_settle_bills(dut):
    """Main test for settle_bills module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (M, N, receipts, expected_output, description)
    # receipts is list of tuples (a, b, p)
    test_cases = [
        (
            4, 2,
            [(0, 1, 1), (2, 3, 1)],
            2,
            "Example 1: two separate debts"
        ),
        (
            5, 5,
            [(0, 1, 3), (1, 2, 3), (2, 3, 3), (3, 4, 3), (4, 0, 3)],
            0,
            "Example 2: cycle cancels out"
        ),
        (
            5, 4,
            [(0, 1, 1), (0, 2, 1), (0, 3, 1), (0, 4, 1)],
            4,
            "Example 3: one person paid for all"
        ),
        (
            3, 2,
            [(0, 1, 10), (1, 2, 10)],
            2,
            "Chain of debts"
        ),
        (
            2, 1,
            [(0, 1, 10)],
            1,
            "Single debt"
        ),
        (
            6, 0,
            [],
            0,
            "No receipts"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (M, N, receipts, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  M={M}, N={N}, expected={expected}")
        
        try:
            # Reset for each test case
            await reset_dut(dut)
            
            # Process receipts
            for idx, (a, b, p) in enumerate(receipts):
                # Wait for rising edge to ensure stability
                await RisingEdge(dut.clk)
                # Set inputs
                dut.receipt_a.value = a
                dut.receipt_b.value = b
                dut.receipt_p.value = p
                dut.receipt_valid.value = 1
                dut.last.value = 1 if idx == len(receipts)-1 else 0
                # Wait for one clock cycle
                await RisingEdge(dut.clk)
                dut.receipt_valid.value = 0
                dut.last.value = 0
            
            # If no receipts, we still need to transition to processing state
            if N == 0:
                # Just wait a few cycles for the state machine to advance
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
            
            # Wait for computation to complete
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
