import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH CONFIGURATION
# ============================================================================

DATA_WIDTH = 10          # w_i, h_i are 10 bits
MAX_N = 8                # Maximum number of friends
CLK_PERIOD_NS = 10       # Clock period
MAX_CYCLES = 2000        # Timeout for done signal

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_group_photo(dut):
    """Test the group photo area minimization module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, [(w,h)...], expected_area)
    test_cases = [
        (3, [(10,1), (20,2), (30,3)], 180),
        (3, [(3,1), (2,2), (4,3)], 21),
        (1, [(5,10)], 50),
        (2, [(1,1000), (1000,1)], 2000),
        (4, [(573,7), (169,9), (447,7), (947,3)], 19224),
    ]
    
    for n, friends, expected in test_cases:
        # Pad friends to MAX_N
        padded_friends = friends + [(0,0)] * (MAX_N - len(friends))
        
        # Set inputs
        dut.n.value = n
        for i, (w, h) in enumerate(padded_friends):
            getattr(dut, f'w{i}').value = clamp_to_width(w, DATA_WIDTH)
            getattr(dut, f'h{i}').value = clamp_to_width(h, DATA_WIDTH)
        
        # Test for all possible max_h (1-255)
        min_area = 0x3FFFFFF  # Large initial value
        
        for max_h in range(1, 256):
            dut.max_h.value = max_h
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done with timeout
            cycles = 0
            while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                await RisingEdge(dut.clk)
                cycles += 1
                if cycles > MAX_CYCLES:
                    raise TestFailure(f"Timeout for max_h={max_h}")
            
            # Read area
            area_val = int(dut.area.value)
            if area_val < min_area:
                min_area = area_val
        
        # Verify result
        if min_area != expected:
            raise TestFailure(f"Test failed: n={n}, expected={expected}, got={min_area}")
        
        dut._log.info(f"Test passed: n={n}, area={min_area}")
        
        # Cool down between tests
        await Timer(100, units='ns')

    dut._log.info("All tests passed!")