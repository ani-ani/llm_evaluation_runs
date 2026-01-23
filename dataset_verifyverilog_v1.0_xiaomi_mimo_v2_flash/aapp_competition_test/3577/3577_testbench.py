import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
COORD_WIDTH = 5      # 5-bit coordinates (0-31)
DAYS = 8             # Maximum days to process
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
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
async def test_flower_counter(dut):
    """Test the flower counter module with sample inputs."""
    
    # Verify required signals exist
    required_signals = ['clk', 'rst_n', 'start', 'L_in', 'R_in', 'new_flowers', 'done']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (L, R, expected_new_flowers)
    # Sample Input 1
    test_cases = [
        (1, 4, 0),  # Day 1
        (3, 7, 1),  # Day 2
        (1, 6, 1),  # Day 3
        (2, 6, 2),  # Day 4
    ]
    
    # Sample Input 2 (as additional test)
    test_cases_2 = [
        (1, 3, 0),
        (3, 5, 0),
        (3, 9, 0),
        (2, 4, 3),
        (3, 8, 2),
    ]
    
    passed = 0
    failed = 0
    
    # Helper to run one test case
    async def run_test(L, R, expected, day_num):
        nonlocal passed, failed
        
        cocotb.log.info(f"Day {day_num}: L={L}, R={R}, expected={expected}")
        
        try:
            # Apply inputs and pulse start
            dut.L_in.value = clamp_to_width(L, COORD_WIDTH)
            dut.R_in.value = clamp_to_width(R, COORD_WIDTH)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.new_flowers.value):
                raise TestFailure("new_flowers is undefined (X/Z)")
            
            result = int(dut.new_flowers.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: new_flowers = {result}")
            passed += 1
            
            # Wait for DONE state to transition back to IDLE
            await RisingEdge(dut.clk)
            await FallingEdge(dut.done)
            await RisingEdge(dut.clk)
            
            return True
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            return False
    
    # Run first sample
    cocotb.log.info("="*60)
    cocotb.log.info("Running Sample Input 1")
    cocotb.log.info("="*60)
    for i, (L, R, expected) in enumerate(test_cases):
        if i >= DAYS:
            cocotb.log.warning(f"Skipping day {i+1} (exceeds DAYS={DAYS})")
            break
        await run_test(L, R, expected, i+1)
    
    # Run second sample
    cocotb.log.info("="*60)
    cocotb.log.info("Running Sample Input 2")
    cocotb.log.info("="*60)
    for i, (L, R, expected) in enumerate(test_cases_2):
        day_num = len(test_cases) + i + 1
        if day_num > DAYS:
            cocotb.log.warning(f"Skipping day {day_num} (exceeds DAYS={DAYS})")
            break
        await run_test(L, R, expected, day_num)
    
    # Summary
    cocotb.log.info("="*60)
    cocotb.log.info(f"FINAL RESULTS: {passed}/{passed+failed} tests passed")
    cocotb.log.info("="*60)
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")