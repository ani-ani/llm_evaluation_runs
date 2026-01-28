import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4      # Strength: 0-9
ADDR_WIDTH = 6      # 64 addresses for 8x8
RESULT_WIDTH = 16   # Cost: up to ~4800
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.wr.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_strength(dut, index, strength):
    """Write a strength value to DUT memory."""
    dut.addr.value = index
    dut.data_in.value = clamp_to_width(strength, DATA_WIDTH)
    dut.wr.value = 1
    await RisingEdge(dut.clk)
    dut.wr.value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_club_lighting(dut):
    """Main test function for club lighting module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (B, H, grid_string_list, expected_cost)
    # Note: These are adapted from problem examples
    # Since we use 8x8 grid, we'll pad smaller grids with zeros
    test_cases = [
        {
            'B': 9,
            'H': 1,
            'grid': [
                "333333",
                "300003",
                "300003",
                "300003",
                "300003",
                "333333"
            ],
            'expected_cost': 176
        },
        {
            'B': 5,
            'H': 2,
            'grid': [
                "6323226",
                "3000005",
                "2000002",
                "2000002",
                "5000003",
                "6223236"
            ],
            'expected_cost': 66
        }
    ]
    
    for case_idx, test_case in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test Case {case_idx+1}: B={test_case['B']}, H={test_case['H']}")
        cocotb.log.info(f"Grid: {len(test_case['grid'])}x{len(test_case['grid'][0])}")
        cocotb.log.info(f"Expected cost: {test_case['expected_cost']}")
        
        # Set parameters
        dut.threshold.value = test_case['B']
        dut.height.value = test_case['H']
        
        # Write grid strengths to DUT (8x8 grid, fill with 0 for unused cells)
        grid = test_case['grid']
        R = len(grid)
        C = len(grid[0])
        
        for r in range(8):
            for c in range(8):
                idx = r * 8 + c
                if r < R and c < C:
                    strength = int(grid[r][c])
                else:
                    strength = 0
                await write_strength(dut, idx, strength)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while True:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        # Read cost
        if not is_value_defined(dut.cost_out.value):
            raise TestFailure("Cost output is undefined")
        
        cost = int(dut.cost_out.value)
        cocotb.log.info(f"Computed cost: {cost}")
        cocotb.log.info(f"Cycles taken: {cycles}")
        
        # Verify
        if cost != test_case['expected_cost']:
            raise TestFailure(
                f"Test {case_idx+1} failed: expected {test_case['expected_cost']}, got {cost}"
            )
        
        cocotb.log.info(f"Test {case_idx+1} PASSED")
        
        # Reset for next test
        await reset_dut(dut)
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info("All tests PASSED")
