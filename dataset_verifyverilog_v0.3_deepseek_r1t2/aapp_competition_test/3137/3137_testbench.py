import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000
MAX_SIM_TIME = 256

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
async def test_bacteria_simulation(dut):
    """Test bacteria movement simulation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    # Format: (trap_row, trap_col, bacterium0_data, bacterium1_data, expected_result, description)
    # bacterium_data: (start_row, start_col, start_dir, grid)
    test_cases = [
        (
            2, 2,  # trap at (2,2)
            (
                1, 1, 1,  # bacterium0: start at (1,1), direction R (1)
                [
                    [0,1,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0]
                ]
            ),
            None,  # Only one bacterium in this test
            2,  # Expected result: 2 seconds
            "Sample 1: Single bacterium reaches trap in 2 steps"
        ),
        (
            2, 2,  # trap at (2,2)
            (
                3, 4, 1,  # bacterium0: start at (3,4), direction R (1)
                [
                    [2,3,2,7,0,0,0,0],
                    [6,0,0,9,0,0,0,0],
                    [2,1,1,2,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0]
                ]
            ),
            (
                3, 2, 1,  # bacterium1: start at (3,2), direction R (1)
                [
                    [1,3,1,0,0,0,0,0],
                    [2,1,0,1,0,0,0,0],
                    [1,3,0,1,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0]
                ]
            ),
            7,  # Expected result: 7 seconds
            "Sample 2: Two bacteria reach trap at t=7"
        ),
        (
            4, 4,  # trap at (4,4)
            (
                1, 1, 0,  # bacterium0: start at (1,1), direction U (0)
                [
                    [1,0,0,1,0,0,0,0],
                    [0,2,4,0,0,0,0,0],
                    [3,3,2,2,0,0,0,0],
                    [2,3,2,7,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0]
                ]
            ),
            (
                1, 3, 3,  # bacterium1: start at (1,3), direction L (3)
                [
                    [9,5,2,1,0,0,0,0],
                    [2,3,9,0,0,0,0,0],
                    [3,0,2,0,0,0,0,0],
                    [2,4,2,1,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0],
                    [0,0,0,0,0,0,0,0]
                ]
            ),
            295,  # Expected result: 295 seconds
            "Sample 3: Complex case requiring many steps"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (trap_r, trap_col, bact0, bact1, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Set trap position
            dut.trap_row.value = trap_r
            dut.trap_col.value = trap_col
            
            # Set bacterium 0 data
            dut.start_row_0.value = bact0[0]
            dut.start_col_0.value = bact0[1]
            dut.start_dir_0.value = bact0[2]
            for r in range(8):
                for c in range(8):
                    if r < 4 and c < 4:  # Only first 4x4 matters for samples
                        val = bact0[3][r][c]
                    else:
                        val = 0
                    if has_signal(dut, f'grid_0_{r}_{c}'):
                        getattr(dut, f'grid_0_{r}_{c}').value = val
                    else:
                        # Try indexed array
                        if has_signal(dut, 'grid_0'):
                            dut.grid_0[r][c].value = val
            
            # Set bacterium 1 data if present
            if bact1 is not None:
                dut.start_row_1.value = bact1[0]
                dut.start_col_1.value = bact1[1]
                dut.start_dir_1.value = bact1[2]
                for r in range(8):
                    for c in range(8):
                        if r < 4 and c < 4:  # Only first 4x4 matters for samples
                            val = bact1[3][r][c]
                        else:
                            val = 0
                        if has_signal(dut, f'grid_1_{r}_{c}'):
                            getattr(dut, f'grid_1_{r}_{c}').value = val
                        else:
                            if has_signal(dut, 'grid_1'):
                                dut.grid_1[r][c].value = val
            else:
                # Set bacterium 1 to invalid state (row=0)
                dut.start_row_1.value = 0
            
            # Wait a bit for inputs to settle
            await Timer(100, units='ns')
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Handle the special case where result=65535 means never
            if result == 65535:
                if expected != -1:
                    raise TestFailure(f"Expected {expected}, got 65535 (never)")
            else:
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")