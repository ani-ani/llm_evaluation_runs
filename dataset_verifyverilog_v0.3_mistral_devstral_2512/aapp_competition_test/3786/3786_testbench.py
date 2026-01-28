import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
DATA_WIDTH = 4  # 4-bit parent indices for n <= 16
ARRAY_SIZE = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'load'):
        dut.load.value = 0
    
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_apple_tree(dut):
    """Main test function for apple_tree module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, parent_list, expected_result)
    test_cases = [
        (2, [1], 2),           # Node2 child of 1 -> depths:0,1 -> parities:1,1 -> total=2
        (3, [1,1], 1),         # Nodes 2,3 children of 1 -> depths:0,1,1 -> parities:1,0 -> total=1
        (5, [1,2,2,2], 3),     # Tree: 1->2, 2->3,4,5 -> depths:0,1,2,2,2 -> parities:1,1,1 -> total=3
        (4, [1,2,3], 4),       # Chain: 1->2->3->4 -> depths:0,1,2,3 -> all odd counts -> total=4
        (3, [1,2], 3),         # Chain: 1->2->3 -> depths:0,1,2 -> all odd -> total=3
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, parent_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, parents={parent_list}, expected={expected}")
        
        try:
            # Reset for new test case
            await reset_dut(dut)
            
            # Start computation
            await start_computation(dut)
            
            # Wait one cycle for INIT state
            await RisingEdge(dut.clk)
            
            # Provide parent values for nodes 2 to n
            for idx, p_val in enumerate(parent_list):
                # Clamp parent value to DATA_WIDTH bits
                p_clamped = clamp_to_width(p_val, DATA_WIDTH)
                dut.parent.value = p_clamped
                dut.load.value = 1
                await RisingEdge(dut.clk)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Random test
    cocotb.log.info("Running random test...")
    random.seed(42)
    n = 16
    parent_list = [random.randint(1, i) for i in range(1, n)]
    
    # Compute expected result
    depth = [0] * n
    for i in range(1, n):
        depth[i] = depth[parent_list[i-1]-1] + 1
    depth_count = {}
    for d in depth:
        depth_count[d] = depth_count.get(d, 0) + 1
    expected = sum(count % 2 for count in depth_count.values())
    
    try:
        await reset_dut(dut)
        await start_computation(dut)
        await RisingEdge(dut.clk)
        
        for p_val in parent_list:
            dut.parent.value = clamp_to_width(p_val, DATA_WIDTH)
            dut.load.value = 1
            await RisingEdge(dut.clk)
        
        await wait_for_done(dut)
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Random test: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Random test PASS: result = {result}")
        passed += 1
        
    except TestFailure as e:
        cocotb.log.error(f"Random test FAIL: {e}")
        failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
