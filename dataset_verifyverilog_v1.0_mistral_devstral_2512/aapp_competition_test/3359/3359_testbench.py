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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_row(dut, values, element_width=16):
    """Write values to row_data array."""
    for i in range(8):
        if i < len(values):
            dut.row_data[i].value = clamp_to_width(values[i], element_width)
        else:
            dut.row_data[i].value = 0

async def read_count(dut):
    """Read the count output."""
    if is_value_defined(dut.count.value):
        return int(dut.count.value)
    return 0

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_stellar_counter(dut):
    """Test stellar body counting."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Example from problem (5x6 padded to 8x8)
    # Expected: 2 connected components
    test_image = [
        [0x0000, 0xFFFF, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
        [0xFFFF, 0xFFFF, 0x0000, 0xFFFF, 0xFFFF, 0x0000, 0x0000, 0x0000],
        [0x0000, 0x0000, 0x0000, 0xFFFF, 0x0000, 0x0000, 0x0000, 0x0000],
        [0x0000, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0x0000, 0x0000, 0x0000],
        [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
        [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
        [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000],
        [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000]
    ]
    
    expected_count = 2
    
    cocotb.log.info("Test Case 1: Example image with 2 stars")
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Provide 8 rows
    for row in test_image:
        # Wait for WAIT_ROW state
        await RisingEdge(dut.clk)
        
        # Write row data and assert row_valid
        await write_row(dut, row)
        dut.row_valid.value = 1
        await RisingEdge(dut.clk)
        dut.row_valid.value = 0
        
        # Wait for processing (8 cycles for 8 pixels)
        for _ in range(8):
            await RisingEdge(dut.clk)
        
        # Wait for next row or done
        await RisingEdge(dut.clk)
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    result = await read_count(dut)
    
    if result != expected_count:
        raise TestFailure(f"Test Case 1: Expected {expected_count}, got {result}")
    
    cocotb.log.info(f"Test Case 1 PASSED: count = {result}")
    
    # Test case 2: Single bright pixel
    test_image2 = [
        [0x0000]*8,
        [0x0000]*8,
        [0x0000]*8,
        [0x0000, 0x0000, 0x0000, 0xFFFF, 0x0000, 0x0000, 0x0000, 0x0000],
        [0x0000]*8,
        [0x0000]*8,
        [0x0000]*8,
        [0x0000]*8
    ]
    expected_count2 = 1
    
    cocotb.log.info("Test Case 2: Single star")
    
    # Reset for new test
    await reset_dut(dut)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for row in test_image2:
        await RisingEdge(dut.clk)
        await write_row(dut, row)
        dut.row_valid.value = 1
        await RisingEdge(dut.clk)
        dut.row_valid.value = 0
        for _ in range(8):
            await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    await wait_for_done(dut)
    result2 = await read_count(dut)
    
    if result2 != expected_count2:
        raise TestFailure(f"Test Case 2: Expected {expected_count2}, got {result2}")
    
    cocotb.log.info(f"Test Case 2 PASSED: count = {result2}")
    
    # Test case 3: No stars (all black)
    test_image3 = [[0x0000]*8 for _ in range(8)]
    expected_count3 = 0
    
    cocotb.log.info("Test Case 3: No stars")
    
    await reset_dut(dut)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for row in test_image3:
        await RisingEdge(dut.clk)
        await write_row(dut, row)
        dut.row_valid.value = 1
        await RisingEdge(dut.clk)
        dut.row_valid.value = 0
        for _ in range(8):
            await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    await wait_for_done(dut)
    result3 = await read_count(dut)
    
    if result3 != expected_count3:
        raise TestFailure(f"Test Case 3: Expected {expected_count3}, got {result3}")
    
    cocotb.log.info(f"Test Case 3 PASSED: count = {result3}")
    
    cocotb.log.info("All tests passed!")
