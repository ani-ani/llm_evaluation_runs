import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_CYCLES = 50000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def collect_pairs(dut, pairs_list, max_pairs=5000):
    while len(pairs_list) < max_pairs:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.pair_valid.value) and int(dut.pair_valid.value) == 1:
            b = int(dut.beverage.value)
            m = int(dut.main_dish.value)
            pairs_list.append((b, m))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_dessert_finder(dut):
    """Test the dessert finder module with scaled test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (P, expected_count, expected_pairs)
    # P=37: pairs (8,29), (9,28), (11,26), (15,22)
    # P=12: pairs (3,9), (4,8), (5,7)
    test_cases = [
        (37, 4, [(8,29), (9,28), (11,26), (15,22)]),
        (12, 3, [(3,9), (4,8), (5,7)]),
    ]
    
    for p_val, exp_count, exp_pairs in test_cases:
        dut._log.info(f"\nTesting P={p_val}")
        
        # Set P and start pulse
        dut.P.value = p_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect pairs
        pairs = []
        collector = cocotb.start_soon(collect_pairs(dut, pairs))
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Stop collector
        collector.kill()
        
        # Read final count
        count = int(dut.count.value)
        
        # Verify count
        if count != exp_count:
            raise TestFailure(
                f"P={p_val}: Expected count {exp_count}, got {count}"
            )
        
        # Verify pairs (order-independent)
        sorted_pairs = sorted(pairs)
        sorted_expected = sorted(exp_pairs)
        
        if sorted_pairs != sorted_expected:
            raise TestFailure(
                f"P={p_val}: Expected pairs {sorted_expected}, got {sorted_pairs}"
            )
        
        dut._log.info(f"  PASS: Found {count} pairs: {pairs}")
    
    dut._log.info("\nAll tests passed!")