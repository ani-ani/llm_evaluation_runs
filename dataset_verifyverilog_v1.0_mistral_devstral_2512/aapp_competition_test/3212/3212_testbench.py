import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 10
STEP = 10
MAX_Y_STEP = 100
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_buffalo_bill_solver(dut):
    """Test the buffalo_bill_solver module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (num_snakes, list of (x,y,d), path_found, entry_y_step, exit_y_step)
    test_cases = [
        # Sample 1
        (3, [(500,500,499), (0,0,999), (1000,1000,200)], 1, 100, 80),
        # Sample 2
        (4, [(250,250,300), (750,250,300), (250,750,300), (750,750,300)], 0, 0, 0),
        # Sample 3
        (1, [(500,500,500)], 1, 100, 100),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (num_snakes, snakes, exp_path, exp_entry, exp_exit) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: num_snakes={num_snakes}")
        
        # Set num_snakes
        dut.num_snakes.value = num_snakes
        
        # Set snake inputs (for up to 4 snakes)
        for i in range(4):
            if i < num_snakes:
                x, y, d = snakes[i]
                x = clamp_to_width(x, DATA_WIDTH)
                y = clamp_to_width(y, DATA_WIDTH)
                d = clamp_to_width(d, DATA_WIDTH)
                if has_signal(dut, f'snake_x{i}'):
                    getattr(dut, f'snake_x{i}').value = x
                    getattr(dut, f'snake_y{i}').value = y
                    getattr(dut, f'snake_d{i}').value = d
                else:
                    dut.snake_x[i].value = x
                    dut.snake_y[i].value = y
                    dut.snake_d[i].value = d
            else:
                if has_signal(dut, f'snake_x{i}'):
                    getattr(dut, f'snake_x{i}').value = 0
                    getattr(dut, f'snake_y{i}').value = 0
                    getattr(dut, f'snake_d{i}').value = 0
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read outputs
        if not is_value_defined(dut.path_found.value):
            raise TestFailure(f"Test {test_idx+1}: path_found is undefined")
        path_found = int(dut.path_found.value)
        
        if not is_value_defined(dut.entry_y_step.value):
            raise TestFailure(f"Test {test_idx+1}: entry_y_step is undefined")
        entry_y_step = int(dut.entry_y_step.value)
        
        if not is_value_defined(dut.exit_y_step.value):
            raise TestFailure(f"Test {test_idx+1}: exit_y_step is undefined")
        exit_y_step = int(dut.exit_y_step.value)
        
        # Check results
        if path_found != exp_path:
            cocotb.log.error(f"Test {test_idx+1}: expected path_found={exp_path}, got {path_found}")
            failed += 1
            continue
        
        if exp_path == 1:
            if entry_y_step != exp_entry:
                cocotb.log.error(f"Test {test_idx+1}: expected entry_y_step={exp_entry}, got {entry_y_step}")
                failed += 1
                continue
            if exit_y_step != exp_exit:
                cocotb.log.error(f"Test {test_idx+1}: expected exit_y_step={exp_exit}, got {exit_y_step}")
                failed += 1
                continue
        
        # Log success
        if exp_path == 1:
            entry_y = entry_y_step * STEP
            exit_y = exit_y_step * STEP
            cocotb.log.info(f"Test {test_idx+1}: PASS - Entry (0.00, {entry_y:.2f}), Exit (1000.00, {exit_y:.2f})")
        else:
            cocotb.log.info(f"Test {test_idx+1}: PASS - Bill will be bitten")
        passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")