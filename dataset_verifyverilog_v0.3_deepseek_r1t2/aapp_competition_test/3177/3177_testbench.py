import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 2      # Each number 0-3 (representing 1-4)
ARRAY_SIZE = 4      # Fixed N=4
STATE_BITS = 8      # 4 numbers * 2 bits
MAX_DISTANCE = 5    # 5 bits for distance (max 23)
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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def perm_to_bits(perm):
    """Convert permutation list [1,2,3,4] to 8-bit representation."""
    # Map 1->0, 2->1, 3->2, 4->3
    bits = 0
    for i, num in enumerate(perm):
        mapped = num - 1
        bits |= (mapped << (2*i))
    return bits

def bits_to_perm(bits):
    """Convert 8-bit representation back to permutation [1,2,3,4]."""
    perm = []
    for i in range(4):
        val = (bits >> (2*i)) & 0x3
        perm.append(val + 1)
    return perm

def pack_swaps(swaps_list):
    """Pack list of (pos1, pos2) swaps into 24-bit value."""
    # Each swap: 4 bits [3:2]=pos1 (0-indexed), [1:0]=pos2 (0-indexed)
    packed = 0
    for i, (p1, p2) in enumerate(swaps_list):
        # Convert to 0-indexed
        p1_0 = p1 - 1
        p2_0 = p2 - 1
        packed |= (p1_0 << (i*4 + 2)) | (p2_0 << (i*4))
    return packed

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sort_minimum_swaps(dut):
    """Test the sort_minimum_swaps module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.initial_perm.value = 0
    dut.swaps.value = 0
    dut.num_swaps.value = 0
    
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted for N=4
    test_cases = [
        # (initial_perm, swaps_list, expected_min_swaps, description)
        (
            [2, 1, 3, 4],  # Swap first two
            [(1, 2)],       # Only swap positions 1 and 2 (0-indexed: 0,1)
            1,
            "Simple swap of first two elements"
        ),
        (
            [2, 1, 3, 4],  # Same permutation
            [(1, 3), (2, 3)],  # Swaps: (1,3) and (2,3) in 1-indexed
            3,
            "Three swaps needed (adapted from example 2)"
        ),
        (
            [1, 2, 3, 4],  # Already sorted
            [(1, 2), (1, 3), (2, 4), (3, 4)],  # Any swaps
            0,
            "Already sorted"
        ),
        (
            [4, 3, 2, 1],  # Fully reversed
            [(1, 2), (2, 3), (3, 4), (1, 4)],  # Some swaps
            2,  # Can swap (1,4) then (2,3) - but depends on available swaps
            "Reversed permutation"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (initial_perm, swaps_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Initial: {initial_perm}")
        cocotb.log.info(f"  Swaps: {swaps_list}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Convert to bit representations
            perm_bits = perm_to_bits(initial_perm)
            swaps_bits = pack_swaps(swaps_list)
            num_swaps = len(swaps_list)
            
            # Set inputs
            dut.initial_perm.value = perm_bits
            dut.swaps.value = swaps_bits
            dut.num_swaps.value = num_swaps
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done with timeout
            cycles = 0
            while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                if cycles > MAX_CYCLES:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                if is_value_defined(dut.error.value) and int(dut.error.value) == 1:
                    raise TestFailure("Error signal asserted")
                await RisingEdge(dut.clk)
                cycles += 1
            
            # Read result
            if not is_value_defined(dut.min_swaps.value):
                raise TestFailure("min_swaps is undefined (X/Z)")
            
            result = int(dut.min_swaps.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: got {result}")
            passed += 1
            
            # Wait a few cycles before next test
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# Additional test for edge case
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_single_element_cycle(dut):
    """Test a case where multiple swaps are needed."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: [3,1,2,4] with swaps (1,2), (2,3) in 1-indexed
    # This forms a 3-cycle: 3->1->2->3
    initial = [3, 1, 2, 4]
    swaps = [(1,2), (2,3)]  # positions (0,1) and (1,2)
    expected = 2  # Two swaps minimum for 3-cycle
    
    dut.initial_perm.value = perm_to_bits(initial)
    dut.swaps.value = pack_swaps(swaps)
    dut.num_swaps.value = len(swaps)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
        if cycles > MAX_CYCLES:
            raise TestFailure("Timeout")
        await RisingEdge(dut.clk)
        cycles += 1
    
    result = int(dut.min_swaps.value)
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    cocotb.log.info(f"3-cycle test passed: {result} swaps")