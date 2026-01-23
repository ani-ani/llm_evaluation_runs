import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
SHIFT_WIDTH = 5
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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

def python_left_rotate(n, d, bits=32):
    """Python reference implementation of left rotation."""
    d = d % bits
    return ((n << d) | (n >> (bits - d))) & ((1 << bits) - 1)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'data_in'):
        dut.data_in.value = 0
    if has_signal(dut, 'shift_amount'):
        dut.shift_amount.value = 0
    
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

async def start_computation(dut, data_in, shift_amount):
    """Pulse start signal and set inputs for one cycle."""
    dut.data_in.value = clamp_to_width(data_in, DATA_WIDTH)
    dut.shift_amount.value = clamp_to_width(shift_amount, SHIFT_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_left_rotate(dut):
    """Test the left bit rotator module."""
    
    # Start clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    else:
        raise TestFailure("Module must have 'clk' signal for sequential operation")
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (data_in, shift_amount, expected_output, description)
    test_cases = [
        (16, 2, 64, "left_rotate(16,2) == 64"),
        (10, 2, 40, "left_rotate(10,2) == 40"),
        (99, 3, 792, "left_rotate(99,3) == 792"),
        (0b0001, 3, 0b1000, "left_rotate(0b0001,3) == 0b1000"),
        (0b0101, 3, 0b101000, "left_rotate(0b0101,3) == 0b101000"),
        (0b11101, 3, 0b11101000, "left_rotate(0b11101,3) == 0b11101000"),
        (0, 5, 0, "left_rotate(0,5) == 0 (zero input)"),
        (0xFFFFFFFF, 1, 0xFFFFFFFF, "left_rotate(0xFFFFFFFF,1) == 0xFFFFFFFF (all ones)"),
        (0x80000000, 1, 1, "left_rotate(0x80000000,1) == 1 (MSB to LSB)"),
        (0x12345678, 4, 0x23456781, "left_rotate(0x12345678,4) == 0x23456781"),
        (0x1, 0, 0x1, "left_rotate(0x1,0) == 0x1 (no shift)"),
        (0x1, 32, 0x1, "left_rotate(0x1,32) == 0x1 (full rotation)"),
        (0x5, 31, 0x80000002, "left_rotate(0x5,31) == 0x80000002"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (data_in, shift_amount, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}/{len(test_cases)}: {description}")
        
        try:
            # Apply inputs and start
            await start_computation(dut, data_in, shift_amount)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.data_out.value):
                raise TestFailure("data_out is undefined (X/Z)")
            
            result = int(dut.data_out.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected} (0x{expected:08X}), got {result} (0x{result:08X})")
            
            cocotb.log.info(f"  PASS: data_out = {result} (0x{result:08X})")
            passed += 1
            
            # Wait one cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")