import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def wait_for_done(dut, max_cycles=1000):
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
async def test_barcode_solver(dut):
    """Test the barcode solver with sample input 1 (n=2)."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Set specifications for sample input 1
    # Row specs: row0: 1, row1: 0
    dut.row0_g1.value = 1
    dut.row0_g2.value = 0
    dut.row1_g1.value = 0
    dut.row1_g2.value = 0
    
    # Column specs: col0: 0, col1: 3
    dut.col0_g1.value = 0
    dut.col0_g2.value = 0
    dut.col1_g1.value = 3
    dut.col1_g2.value = 0
    
    # Start computation
    await start_computation(dut)
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read outputs
    if not is_value_defined(dut.row0_vbars.value) or not is_value_defined(dut.row1_vbars.value) or \
       not is_value_defined(dut.col0_hbars.value) or not is_value_defined(dut.col1_hbars.value):
        raise TestFailure("Output signals are undefined (X/Z)")
    
    row0 = int(dut.row0_vbars.value)
    row1 = int(dut.row1_vbars.value)
    col0 = int(dut.col0_hbars.value)
    col1 = int(dut.col1_hbars.value)
    
    # Expected values from sample output:
    # Row0: "100" -> binary 100 (4) -> decimal 4
    # Row1: "000" -> 0
    # Col0: "000" -> 0
    # Col1: "111" -> 3'b111 is 7
    expected_row0 = 0b100  # 4
    expected_row1 = 0b000  # 0
    expected_col0 = 0b000  # 0
    expected_col1 = 0b111  # 7
    
    if row0 != expected_row0:
        raise TestFailure(f"Row0 bars mismatch: expected {expected_row0:b}, got {row0:b}")
    if row1 != expected_row1:
        raise TestFailure(f"Row1 bars mismatch: expected {expected_row1:b}, got {row1:b}")
    if col0 != expected_col0:
        raise TestFailure(f"Col0 bars mismatch: expected {expected_col0:b}, got {col0:b}")
    if col1 != expected_col1:
        raise TestFailure(f"Col1 bars mismatch: expected {expected_col1:b}, got {col1:b}")
    
    dut._log.info("All outputs match expected values.")