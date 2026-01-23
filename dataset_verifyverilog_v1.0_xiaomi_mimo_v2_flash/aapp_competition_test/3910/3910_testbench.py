import cocotb
from cocotb.triggers import Timer, RisingEdge
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

# ============================================================================
# CONFIGURATION - Match HDL design
# ============================================================================

DATA_WIDTH = 4        # Chair indices (0-15)
COUPLES_MAX = 8
CLK_PERIOD_NS = 10

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_food_assignment(dut):
    """Test food assignment for n couples"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.config_en.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: n=3, chairs 1-6 (0-indexed: 0-5)
    # Pairs: (0,3), (1,4), (2,5)
    n = 3
    couples = [(0,3), (1,4), (2,5)]
    
    # Configuration phase
    for a, b in couples:
        dut.a_in.value = a
        dut.b_in.value = b
        dut.config_en.value = 1
        await RisingEdge(dut.clk)
        dut.config_en.value = 0
        await RisingEdge(dut.clk)
    
    # Set n (number of couples)
    dut.n.value = n
    
    # Wait for computation to finish (done goes high)
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Collect output
    results = []
    for i in range(n):
        if not is_value_defined(dut.output_valid.value) or int(dut.output_valid.value) == 0:
            raise TestFailure(f"Output valid not high for couple {i}")
        
        if not is_value_defined(dut.output_index.value) or int(dut.output_index.value) != i:
            raise TestFailure(f"Output index mismatch: expected {i}, got {safe_int(dut.output_index.value)}")
        
        boy_food = int(dut.output_boy.value)
        girl_food = int(dut.output_girl.value)
        
        # Map to expected output format (1 or 2)
        boy_food = 1 if boy_food == 1 else 2  # 01->1, 10->2
        girl_food = 1 if girl_food == 1 else 2
        
        results.append((boy_food, girl_food))
        await RisingEdge(dut.clk)
    
    # Verify results
    expected = [(1,2), (2,1), (1,2)]  # From example
    
    for i, (exp_boy, exp_girl) in enumerate(expected):
        boy, girl = results[i]
        if (boy, girl) != (exp_boy, exp_girl):
            raise TestFailure(f"Couple {i}: expected ({exp_boy},{exp_girl}), got ({boy},{girl})")
        dut._log.info(f"Couple {i}: Boy={boy}, Girl={girl} [PASS]")
    
    dut._log.info(f"All tests passed!")
