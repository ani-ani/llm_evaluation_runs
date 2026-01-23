import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
GRID_SIZE = 8
MAX_BEACONS = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

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
# SEQUENTIAL MODULE HELPERS
# ============================================================================

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

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_mps_system(dut):
    """Test the Manhattan Positioning System module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (num_beacons, beacons, expected_result, description)
    # beacons format: [(x, y, d), ...]
    test_cases = [
        # Test 1: One solution
        (2, [(0, 0, 5), (10, 0, 6)], (5, 0), "One solution at (5,0)"),
        # Test 2: Uncertain (multiple solutions)
        (2, [(0, 0, 4), (4, 4, 4)], (None, None), "Uncertain - multiple solutions"),
        # Test 3: Impossible
        (2, [(0, 0, 1), (2, 2, 1)], (None, None), "Impossible - no solution"),
        # Test 4: Single beacon test
        (1, [(3, 3, 2)], (5, 3), "Single beacon, multiple possible, but we test detection"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (num_beacons, beacons, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {description}")
        cocotb.log.info(f"  Beacons: {beacons}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Set number of beacons
            dut.num_beacons.value = num_beacons
            
            # Set beacon values
            for i in range(MAX_BEACONS):
                if i < len(beacons):
                    x, y, d = beacons[i]
                    # Convert to signed for Verilog
                    x_signed = from_signed(x, 8)
                    y_signed = from_signed(y, 8)
                    
                    # Set each beacon port
                    if i == 0:
                        dut.beacon0_x.value = x_signed
                        dut.beacon0_y.value = y_signed
                        dut.beacon0_d.value = d
                    elif i == 1:
                        dut.beacon1_x.value = x_signed
                        dut.beacon1_y.value = y_signed
                        dut.beacon1_d.value = d
                    elif i == 2:
                        dut.beacon2_x.value = x_signed
                        dut.beacon2_y.value = y_signed
                        dut.beacon2_d.value = d
                    elif i == 3:
                        dut.beacon3_x.value = x_signed
                        dut.beacon3_y.value = y_signed
                        dut.beacon3_d.value = d
                else:
                    # Clear unused beacons
                    if i == 0:
                        dut.beacon0_x.value = 0
                        dut.beacon0_y.value = 0
                        dut.beacon0_d.value = 0
                    elif i == 1:
                        dut.beacon1_x.value = 0
                        dut.beacon1_y.value = 0
                        dut.beacon1_d.value = 0
                    elif i == 2:
                        dut.beacon2_x.value = 0
                        dut.beacon2_y.value = 0
                        dut.beacon2_d.value = 0
                    elif i == 3:
                        dut.beacon3_x.value = 0
                        dut.beacon3_y.value = 0
                        dut.beacon3_d.value = 0
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.done.value):
                raise TestFailure("Done signal undefined")
            
            result_x = int(dut.result_x.value) if is_value_defined(dut.result_x.value) else None
            result_y = int(dut.result_y.value) if is_value_defined(dut.result_y.value) else None
            impossible = int(dut.impossible.value) if is_value_defined(dut.impossible.value) else 0
            uncertain = int(dut.uncertain.value) if is_value_defined(dut.uncertain.value) else 0
            
            cocotb.log.info(f"  Got: X={result_x}, Y={result_y}, Impossible={impossible}, Uncertain={uncertain}")
            
            # Verify expected result
            exp_x, exp_y = expected
            
            if exp_x is None and exp_y is None:
                # Expected uncertain or impossible
                if impossible:
                    if description == "Impossible - no solution":
                        cocotb.log.info("  PASS: Correctly detected impossible")
                        passed += 1
                    else:
                        raise TestFailure(f"Expected uncertain but got impossible")
                elif uncertain:
                    if description == "Uncertain - multiple solutions":
                        cocotb.log.info("  PASS: Correctly detected uncertain")
                        passed += 1
                    else:
                        raise TestFailure(f"Expected impossible but got uncertain")
                else:
                    raise TestFailure("Expected uncertain or impossible but got neither")
            else:
                # Expected specific coordinates
                if impossible:
                    raise TestFailure(f"Expected ({exp_x},{exp_y}) but got impossible")
                if uncertain:
                    raise TestFailure(f"Expected ({exp_x},{exp_y}) but got uncertain")
                if result_x != exp_x or result_y != exp_y:
                    raise TestFailure(f"Expected ({exp_x},{exp_y}), got ({result_x},{result_y})")
                cocotb.log.info(f"  PASS: Got expected ({exp_x},{exp_y})")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
