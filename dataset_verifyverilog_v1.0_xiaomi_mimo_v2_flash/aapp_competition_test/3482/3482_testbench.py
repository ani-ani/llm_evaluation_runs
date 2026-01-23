import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 10
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_transit_card(dut):
    """Main test function."""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (l, p, d, t, n, away_intervals, expected_cost, description)
    test_cases = [
        # Test case 1: no away trips
        (
            3, [20,15,10], [7,7], 16, 0, [], 265,
            "No away trips, t=16"
        ),
        # Test case 2: with away trips
        (
            3, [20,15,10], [7,7], 16, 2, [(3,3), (9,12)], 220,
            "Two away trips within t=16"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (l, p, d, t, n, away_intervals, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {idx+1}: {description}")
        
        try:
            # Set inputs
            dut.l.value = l
            dut.p0.value = p[0]
            dut.p1.value = p[1] if l > 1 else 0
            dut.p2.value = p[2] if l > 2 else 0
            dut.p3.value = p[3] if l > 3 else 0
            dut.d0.value = d[0] if l > 1 else 0
            dut.d1.value = d[1] if l > 2 else 0
            dut.d2.value = d[2] if l > 3 else 0
            dut.n.value = n
            dut.t.value = t
            
            # Set away intervals
            away_a_signals = [dut.away_a0, dut.away_a1, dut.away_a2, dut.away_a3]
            away_b_signals = [dut.away_b0, dut.away_b1, dut.away_b2, dut.away_b3]
            for i in range(4):
                if i < len(away_intervals):
                    away_a_signals[i].value = away_intervals[i][0]
                    away_b_signals[i].value = away_intervals[i][1]
                else:
                    away_a_signals[i].value = 0
                    away_b_signals[i].value = 0
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
