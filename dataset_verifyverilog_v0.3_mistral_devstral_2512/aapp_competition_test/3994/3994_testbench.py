import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_lights_max(dut):
    """Test lights maximum finder with multiple test cases."""
    
    # Configuration
    NUM_LIGHTS = 8
    MAX_TIME = 120
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (initial_state, a_list, b_list, expected_max)
    test_cases = [
        # Original test case 1
        (0b10100000,  # initial states: lights 0 and 2 are on
         [3, 3, 3, 0, 0, 0, 0, 0],  # periods
         [3, 2, 1, 0, 0, 0, 0, 0],  # offsets
         2),  # expected max
        
        # Original test case 2  
        (0b11110000,  # all 4 lights on
         [3, 5, 3, 3, 0, 0, 0, 0],
         [4, 2, 1, 2, 0, 0, 0, 0],
         4),
        
        # Original test case 3
        (0b01110000,  # lights 1,2,3 on initially
         [5, 5, 2, 3, 4, 1, 0, 0],
         [3, 5, 4, 5, 2, 5, 0, 0],
         6),  # Note: this becomes 6 when scaled to 8 lights with padding
    ]
    
    for test_idx, (init_state, a_list, b_list, expected) in enumerate(test_cases):
        dut._log.info(f"\nTest case {test_idx + 1}: Initial={init_state:b}, Expected={expected}")
        
        # Wait for done to be low
        await RisingEdge(dut.clk)
        
        # Set initial state and parameters
        dut.initial_state.value = init_state
        
        # Set a and b arrays
        for i in range(NUM_LIGHTS):
            # Use getattr for individual signals since we declared them as separate ports
            if i < len(a_list):
                getattr(dut, f'a{i}').value = a_list[i]
            else:
                getattr(dut, f'a{i}').value = 0
                
            if i < len(b_list):
                getattr(dut, f'b{i}').value = b_list[i]
            else:
                getattr(dut, f'b{i}').value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done state (DONE = 4)
        timeout = 2000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            state = safe_int(dut.state.value)
            if state == 4:  # DONE state
                break
        else:
            raise TestFailure(f"Timeout waiting for completion in test {test_idx+1}")
        
        # Read result
        if is_value_defined(dut.max_count.value):
            result = int(dut.max_count.value)
            dut._log.info(f"  Result: {result}, Expected: {expected}")
            
            # Check result
            if result != expected:
                raise TestFailure(f"Test {test_idx+1} failed: expected {expected}, got {result}")
        else:
            raise TestFailure(f"Output max_count is undefined in test {test_idx+1}")
    
    dut._log.info("\nAll tests passed!")
