import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 10          # Shares: 1-1000
DAY_WIDTH = 9            # Days: 1-365
SUM_WIDTH = 20           # Sum: max 1,000,000
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
# PARSE INPUT STRING
# ============================================================================

def parse_input(input_str):
    """Parse input string into list of (day, shares) records."""
    lines = input_str.strip().split('\n')
    idx = 0
    C = int(lines[idx]); idx += 1
    records = []
    
    for _ in range(C):
        K = int(lines[idx]); idx += 1
        for _ in range(K):
            parts = lines[idx].split()
            idx += 1
            shares = int(parts[0])
            day = int(parts[1])
            records.append((day, shares))
    
    return records

# ============================================================================
# RESET SEQUENCE
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.in_valid.value = 0
    dut.in_day.value = 0
    dut.in_shares.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_share_tracker(dut):
    """Test ShareTracker module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test cases: input string -> expected output string
    test_cases = [
        (
            "3\n2\n20 100\n100 10\n1\n150 50\n1\n150 100\n",
            "100 250 320"
        ),
        (
            "3\n2\n200 63\n100 25\n2\n50 278\n100 63\n2\n50 25\n100 278\n",
            "150 350 350"
        )
    ]
    
    all_passed = True
    
    for test_idx, (input_str, expected_output) in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test Case {test_idx + 1}")
        dut._log.info(f"{'='*60}")
        
        # Parse input
        records = parse_input(input_str)
        dut._log.info(f"Parsed {len(records)} records")
        
        # Reset
        await reset_dut(dut)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed records one per cycle
        dut._log.info("Feeding records...")
        for day, shares in records:
            dut.in_valid.value = 1
            dut.in_day.value = day
            dut.in_shares.value = shares
            await RisingEdge(dut.clk)
        
        # Deassert valid
        dut.in_valid.value = 0
        dut.in_day.value = 0
        dut.in_shares.value = 0
        
        # Wait for output state (give it a few cycles)
        await Timer(500, units='ns')
        
        # Collect outputs
        collected = []
        cycles = 0
        
        while cycles < MAX_CYCLES:
            # Wait for valid or done
            await RisingEdge(dut.clk)
            cycles += 1
            
            if is_value_defined(dut.out_valid.value) and int(dut.out_valid.value) == 1:
                day = int(dut.out_day.value)
                shares = int(dut.out_shares.value)
                collected.append((day, shares))
                dut._log.info(f"Output: Day {day} = {shares} shares")
            
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                dut._log.info("Done signal received")
                break
        
        # Format output
        output_str = ' '.join([str(shares) for _, shares in collected])
        
        dut._log.info(f"Expected: {expected_output}")
        dut._log.info(f"Got:      {output_str}")
        
        # Check
        if output_str == expected_output:
            dut._log.info(f"Test {test_idx + 1}: PASS")
        else:
            dut._log.error(f"Test {test_idx + 1}: FAIL")
            all_passed = False
            # Don't raise yet, run all tests
    
    if not all_passed:
        raise TestFailure("Some tests failed")
    
    dut._log.info(f"\n{'='*60}")
    dut._log.info("All tests passed!")
    dut._log.info(f"{'='*60}")