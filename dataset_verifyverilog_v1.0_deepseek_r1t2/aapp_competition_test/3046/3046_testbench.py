import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 16
ARRAY_SIZE = 8
IDX_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

async def write_array(dut, prefix, values, element_width):
    """Write values to array elements."""
    for i, val in enumerate(values):
        port_r = f"{prefix}_r"
        port_c = f"{prefix}_c"
        if has_signal(dut, port_r) and has_signal(dut, port_c):
            getattr(dut, port_r)[i].value = clamp_to_width(val[0], element_width)
            getattr(dut, port_c)[i].value = clamp_to_width(val[1], element_width)
        else:
            raise TestFailure(f"Cannot find array ports: {prefix}_r[{i}] or {prefix}_c[{i}]")

async def read_array(dut, prefix, size):
    """Read array values."""
    results = []
    for i in range(size):
        port_r = f"{prefix}_r"
        port_c = f"{prefix}_c"
        if has_signal(dut, port_r) and has_signal(dut, port_c):
            r_val = safe_int(getattr(dut, port_r)[i].value)
            c_val = safe_int(getattr(dut, port_c)[i].value)
            results.append((r_val, c_val))
        else:
            results.append(None)
    return results

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_rectangle_matcher(dut):
    """Test the rectangle matcher module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (tl_list, br_list, expected_match or None for error)
    test_cases = [
        ([(4,7), (9,8)], [(14,17), (19,18)], [2,1]),  # Example 1
        ([(4,7), (14,17)], [(9,8), (19,18)], [1,2]),  # Example 2
        ([(4,8), (9,7)], [(14,18), (19,17)], None),   # Error
        ([(1,1), (4,8), (8,4)], [(10,6), (6,10), (10,10)], None),  # Error
    ]
    
    passed = 0
    failed = 0
    
    for i, (tl_list, br_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: TL={tl_list}, BR={br_list}")
        
        # Write inputs
        await write_array(dut, 'tl', tl_list, DATA_WIDTH)
        await write_array(dut, 'br', br_list, DATA_WIDTH)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done or error
        try:
            await wait_for_done(dut)
            
            # Check error flag
            if is_value_defined(dut.error.value) and int(dut.error.value) == 1:
                if expected is None:
                    cocotb.log.info("  PASS: Correctly detected error")
                    passed += 1
                else:
                    cocotb.log.error(f"  FAIL: Unexpected error")
                    failed += 1
            else:
                if expected is None:
                    cocotb.log.error(f"  FAIL: Expected error but got valid result")
                    failed += 1
                else:
                    # Read matches
                    results = []
                    for j in range(len(tl_list)):
                        if is_value_defined(dut.match[j].value):
                            results.append(int(dut.match[j].value))
                        else:
                            results.append(0)
                    
                    if results == expected:
                        cocotb.log.info(f"  PASS: matches = {results}")
                        passed += 1
                    else:
                        cocotb.log.error(f"  FAIL: expected {expected}, got {results}")
                        failed += 1
        
        except TestFailure as e:
            if expected is None:
                cocotb.log.info(f"  PASS: Correctly detected error ({e})")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: {e}")
                failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")