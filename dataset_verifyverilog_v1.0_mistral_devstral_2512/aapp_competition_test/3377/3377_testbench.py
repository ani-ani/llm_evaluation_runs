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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
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
# TEST CASE DEFINITIONS
# ============================================================================

TEST_CASES = [
    {
        'name': 'Sample 1: 5 points with dependencies (scaled to 4)',
        'n': 4,  # Scaled from 5 to 4
        'dry_plan': [1, 2, 3, 1, 4, 2, 3],  # Scaled: removed step 5 (point 5)
        'expected': [1, 2, 3, 1, 4],  # Expected wet plan
        'expected_possible': True,
        'dependencies': {
            1: 0,      # No dependencies
            2: 1,      # Depends on 1 (bit 0)
            3: 1,      # Depends on 1 (bit 0)
            4: 0b0110, # Depends on 2 and 3 (bits 1 and 2)
        }
    },
    {
        'name': 'Sample 2: 3 points (scaled to 4)',
        'n': 3,  # Fits within 4
        'dry_plan': [1, 2, 1, 3],
        'expected': [1, 2, 1, 3],
        'expected_possible': True,
        'dependencies': {
            1: 0,
            2: 1,      # Depends on 1 (bit 0)
            3: 0b0010  # Depends on 2 (bit 1)
        }
    }
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_peg_planner(dut):
    """Test the peg planner module with scaled test cases."""
    
    # Configuration
    MAX_N = 4
    MAX_STEPS = 8
    DATA_WIDTH = 4
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test each case
    for test_case in TEST_CASES:
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Testing: {test_case['name']}")
        cocotb.log.info(f"{'='*60}")
        
        # Check if test fits HDL constraints
        if test_case['n'] > MAX_N:
            cocotb.log.warning(f"Skipping - n={test_case['n']} exceeds MAX_N={MAX_N}")
            continue
        
        if len(test_case['dry_plan']) > MAX_STEPS:
            cocotb.log.warning(f"Skipping - dry_plan too long")
            continue
        
        # 1. LOAD DEPENDENCIES
        cocotb.log.info("Phase 1: Loading dependencies...")
        dut.point_id.value = 0
        dut.dep_mask.value = 0
        dut.dep_valid.value = 0
        await RisingEdge(dut.clk)
        
        for point in range(1, test_case['n'] + 1):
            dep_val = test_case['dependencies'].get(point, 0)
            dut.point_id.value = point
            dut.dep_mask.value = dep_val
            dut.dep_valid.value = 1
            await RisingEdge(dut.clk)
            cocotb.log.info(f"  Point {point}: deps = {dep_val:04b}")
        
        # Signal end of dependencies
        dut.point_id.value = 0
        dut.dep_valid.value = 1
        await RisingEdge(dut.clk)
        dut.dep_valid.value = 0
        await RisingEdge(dut.clk)
        
        # 2. LOAD DRY PLAN
        cocotb.log.info("Phase 2: Loading dry plan...")
        dut.dry_valid.value = 0
        
        for step in test_case['dry_plan']:
            dut.dry_step.value = step
            dut.dry_valid.value = 1
            await RisingEdge(dut.clk)
            cocotb.log.info(f"  Dry step: {step}")
        
        # Signal end of dry plan
        dut.dry_step.value = 0
        dut.dry_valid.value = 1
        await RisingEdge(dut.clk)
        dut.dry_valid.value = 0
        await RisingEdge(dut.clk)
        
        # 3. START PROCESSING
        cocotb.log.info("Phase 3: Processing...")
        await start_computation(dut)
        
        # Wait for processing to complete
        await wait_for_done(dut, max_cycles=1000)
        
        # 4. READ WET PLAN
        cocotb.log.info("Phase 4: Reading wet plan...")
        wet_plan = []
        
        # Check if solution possible
        if not is_value_defined(dut.possible.value):
            raise TestFailure("Possible signal undefined")
        
        possible = int(dut.possible.value)
        cocotb.log.info(f"  Possible: {possible}")
        
        if possible != test_case['expected_possible']:
            raise TestFailure(f"Expected possible={test_case['expected_possible']}, got {possible}")
        
        if possible:
            # Read wet steps
            for _ in range(32):  # Max wet steps
                if not is_value_defined(dut.wet_valid.value):
                    break
                if int(dut.wet_valid.value) == 1:
                    if is_value_defined(dut.wet_step.value):
                        step = int(dut.wet_step.value)
                        # Convert from unsigned to signed
                        if step >= (1 << (DATA_WIDTH - 1)):
                            step -= (1 << DATA_WIDTH)
                        wet_plan.append(step)
                        cocotb.log.info(f"  Wet step: {step}")
                await RisingEdge(dut.clk)
        
        # 5. VERIFY
        cocotb.log.info("Phase 5: Verification...")
        if possible:
            if wet_plan != test_case['expected']:
                raise TestFailure(
                    f"Test '{test_case['name']}' failed!\n"
                    f"Expected: {test_case['expected']}\n"
                    f"Got: {wet_plan}"
                )
            cocotb.log.info(f"  PASS: Wet plan matches expected")
            cocotb.log.info(f"  Wet plan: {wet_plan}")
        else:
            cocotb.log.info(f"  PASS: Correctly identified as impossible")
        
        # Reset for next test
        await reset_dut(dut)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info("ALL TESTS PASSED")
    cocotb.log.info(f"{'='*60}")
