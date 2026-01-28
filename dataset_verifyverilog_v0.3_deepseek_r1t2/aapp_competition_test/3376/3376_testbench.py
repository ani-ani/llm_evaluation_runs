import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
NUM_FAMILIES = 4
MAX_KINDS = 8
MAX_CATCHES = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# TEST CASES - SCALED DOWN
# ============================================================================

# Test case 1: From sample input, scaled down
# Original had 3 families, 7 catches. We'll use 2 families, 4 catches.
test_case_1 = {
    "family_sizes": [2, 2, 0, 0],  # 2 families, each with 2 kinds
    "evolution_costs": [3, 0, 7, 0, 0, 0, 0, 0],  # family1: cost3, family2: cost7
    "catch_times": [0, 5, 10, 15, 0, 0, 0, 0],  # 4 catches
    "catch_names": [0b0001, 0b0001, 0b0101, 0b0110, 0, 0, 0, 0],  # family0_type1, family0_type1, family1_type1, family1_type2
    "expected": 500  # Simplified expected result
}

# Test case 2: Simple case with one catch
# 1 family with 1 kind (no evolution), 1 catch at time 0
test_case_2 = {
    "family_sizes": [1, 0, 0, 0],
    "evolution_costs": [0, 0, 0, 0, 0, 0, 0, 0],
    "catch_times": [0, 0, 0, 0, 0, 0, 0, 0],
    "catch_names": [0, 0, 0, 0, 0, 0, 0, 0],
    "expected": 100  # Only catch XP during window
}

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_nudgemon_go(dut):
    """Test the nudgemon_go module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    test_cases = [test_case_1, test_case_2]
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}")
        
        try:
            # Pack inputs into the expected format
            # Family sizes: 4 bits per family
            family_sizes_packed = 0
            for j, size in enumerate(tc['family_sizes']):
                family_sizes_packed |= (size & 0xF) << (j*4)
            dut.family_sizes.value = family_sizes_packed
            
            # Evolution costs: 8 bits per cost, 4 costs per family
            evolution_costs_packed = 0
            for j, cost in enumerate(tc['evolution_costs']):
                evolution_costs_packed |= (cost & 0xFF) << (j*8)
            dut.evolution_costs.value = evolution_costs_packed
            
            # Catch times: 8 bits per catch
            catch_times_packed = 0
            for j, time in enumerate(tc['catch_times']):
                catch_times_packed |= (time & 0xFF) << (j*8)
            dut.catch_times.value = catch_times_packed
            
            # Catch names: 4 bits per catch (2 for family, 2 for type)
            catch_names_packed = 0
            for j, name in enumerate(tc['catch_names']):
                catch_names_packed |= (name & 0xF) << (j*4)
            dut.catch_names.value = catch_names_packed
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.max_xp.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.max_xp.value)
            expected = tc['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: max_xp = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
