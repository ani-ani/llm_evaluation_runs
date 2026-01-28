import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
OUTPUT_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 100

# MANDATORY HELPERS
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Enhanced helper for array/array-like input
async def write_array(dut, vals, width):
    """Write to 6 separate input ports if they exist as arr_0..arr_5, otherwise try arr[0..5]"""
    for i, v in enumerate(vals):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(v, width)
        elif has_signal(dut, 'arr'):
            dut.arr[i].value = clamp_to_width(v, width)
        else:
            # Direct signal access for a1..a6 naming
            sig_name = f'a{i+1}'
            if has_signal(dut, sig_name):
                getattr(dut, sig_name).value = clamp_to_width(v, width)
            else:
                raise TestFailure(f"Cannot find input port for index {i}")

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Calculate expected result using the formula
def calculate_expected(a1, a2, a3, a5):
    return (a1 + a2 + a3) ** 2 - a1 ** 2 - a3 ** 2 - a5 ** 2

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_hexagon_triangles(dut):
    # Setup clock and reset if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just wait
        await Timer(100, units='ns')
    
    # Test cases based on provided examples
    test_cases = [
        # (a1, a2, a3, a4, a5, a6) -> expected triangles
        (1, 1, 1, 1, 1, 1, 6),
        (1, 2, 1, 2, 1, 2, 13),
        (2, 4, 5, 3, 3, 6, 83),
        (45, 19, 48, 18, 46, 21, 6099),
        (1000, 1000, 1000, 1000, 1000, 1000, 6000000),
        (1, 1, 1000, 1, 1, 1000, 4002),
        (1000, 1000, 1, 1000, 1000, 1, 2004000),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a1, a2, a3, a4, a5, a6, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input ({a1}, {a2}, {a3}, {a4}, {a5}, {a6})")
        
        try:
            # Write all 6 sides to input ports
            if has_signal(dut, 'a1'):
                dut.a1.value = clamp_to_width(a1, DATA_WIDTH)
                dut.a2.value = clamp_to_width(a2, DATA_WIDTH)
                dut.a3.value = clamp_to_width(a3, DATA_WIDTH)
                dut.a4.value = clamp_to_width(a4, DATA_WIDTH)
                dut.a5.value = clamp_to_width(a5, DATA_WIDTH)
                dut.a6.value = clamp_to_width(a6, DATA_WIDTH)
            else:
                # Try array-like access
                await write_array(dut, [a1, a2, a3, a4, a5, a6], DATA_WIDTH)
            
            if is_seq:
                # Start the computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined")
                
                result = int(dut.result.value)
            else:
                # Combinational - result should be immediately available
                await Timer(10, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined")
                result = int(dut.result.value)
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: Got {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_edge_cases(dut):
    # Test with maximum values and corner cases
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Edge case: all sides 1000 (maximum)
    a1, a2, a3, a4, a5, a6 = 1000, 1000, 1000, 1000, 1000, 1000
    expected = 6000000  # (3000)^2 - 3*(1000)^2 = 9e6 - 3e6 = 6e6
    
    try:
        if has_signal(dut, 'a1'):
            dut.a1.value = clamp_to_width(a1, DATA_WIDTH)
            dut.a2.value = clamp_to_width(a2, DATA_WIDTH)
            dut.a3.value = clamp_to_width(a3, DATA_WIDTH)
            dut.a4.value = clamp_to_width(a4, DATA_WIDTH)
            dut.a5.value = clamp_to_width(a5, DATA_WIDTH)
            dut.a6.value = clamp_to_width(a6, DATA_WIDTH)
        else:
            await write_array(dut, [a1, a2, a3, a4, a5, a6], DATA_WIDTH)
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            result = int(dut.result.value)
        else:
            await Timer(10, units='ns')
            result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Max values: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Edge case test PASSED: {result}")
        
    except TestFailure as e:
        cocotb.log.error(f"Edge case FAIL: {e}")
        raise

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_reset_behavior(dut):
    # Test that reset clears all state
    is_seq = has_signal(dut, 'clk')
    if not is_seq:
        cocotb.log.info("Skipping reset test for combinational module")
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # After reset, done should be 0
    if is_value_defined(dut.done.value) and int(dut.done.value) != 0:
        raise TestFailure(f"Reset failed: done = {dut.done.value}, expected 0")
    
    # After reset, result should be 0 (if output registered)
    if is_value_defined(dut.result.value) and int(dut.result.value) != 0:
        raise TestFailure(f"Reset failed: result = {dut.result.value}, expected 0")
    
    cocotb.log.info("Reset test PASSED")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_multiple_operations(dut):
    # Test multiple computations back-to-back
    is_seq = has_signal(dut, 'clk')
    if not is_seq:
        cocotb.log.info("Skipping multi-operation test for combinational module")
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_inputs = [
        (1, 1, 1, 1, 1, 1, 6),
        (1, 2, 1, 2, 1, 2, 13),
        (2, 4, 5, 3, 3, 6, 83),
    ]
    
    for i, (a1, a2, a3, a4, a5, a6, expected) in enumerate(test_inputs):
        # Write inputs
        if has_signal(dut, 'a1'):
            dut.a1.value = clamp_to_width(a1, DATA_WIDTH)
            dut.a2.value = clamp_to_width(a2, DATA_WIDTH)
            dut.a3.value = clamp_to_width(a3, DATA_WIDTH)
            dut.a4.value = clamp_to_width(a4, DATA_WIDTH)
            dut.a5.value = clamp_to_width(a5, DATA_WIDTH)
            dut.a6.value = clamp_to_width(a6, DATA_WIDTH)
        else:
            await write_array(dut, [a1, a2, a3, a4, a5, a6], DATA_WIDTH)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Verify result
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Operation {i+1}: Expected {expected}, got {result}")
        
        # Wait one cycle before next operation
        await RisingEdge(dut.clk)
    
    cocotb.log.info("Multiple operations test PASSED")
