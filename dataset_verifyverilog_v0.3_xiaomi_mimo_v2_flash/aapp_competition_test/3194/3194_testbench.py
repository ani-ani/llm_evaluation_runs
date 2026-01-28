import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
T_WIDTH = 8
ARRAY_SIZE = 8
PACKED_WIDTH = 16 * ARRAY_SIZE
RESULT_WIDTH = 1
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
async def write_packed_array(dut, values, element_width=16):
    """Write packed array values to the dut."""
    packed_value = 0
    for i, val in enumerate(values):
        # Ensure value fits in 16 bits
        clamped = clamp_to_width(val, element_width)
        packed_value |= (clamped << (i * element_width))
    dut.arr.value = packed_value

async def read_packed_array(dut, size, element_width=16):
    """Read packed array values from the dut."""
    if not is_value_defined(dut.arr.value):
        return [None] * size
    
    packed_value = int(dut.arr.value)
    results = []
    for i in range(size):
        val = (packed_value >> (i * element_width)) & ((1 << element_width) - 1)
        results.append(val)
    return results

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_module(dut):
    """Main test function."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (n, t, list_of_a, list_of_b, expected_result, description)
    test_cases = [
        # Example 1: 2 tasks, t=10, windows [0,15] and [5,20] -> yes
        (2, 10, [0, 5], [15, 20], 1, 'Two tasks overlapping, schedule possible'),
        # Example 2: 2 tasks, t=10, windows [1,15] and [0,20] -> no
        (2, 10, [1, 0], [15, 20], 0, 'Two tasks, first starts later, cannot schedule both'),
        # Example 3: 2 tasks, t=10, windows [5,30] and [10,20] -> yes
        (2, 10, [5, 10], [30, 20], 1, 'Two tasks, second ends earlier, schedule possible'),
        # Additional test case: single task
        (1, 5, [0], [10], 1, 'Single task, trivial'),
        # Additional test case: three tasks
        (3, 5, [0, 2, 6], [10, 8, 15], 1, 'Three tasks, schedule possible'),
        # Additional test case: three tasks, impossible
        (3, 5, [0, 1, 2], [5, 6, 7], 0, 'Three tasks, windows too tight'),
        # Additional test case: exactly at boundaries
        (2, 10, [0, 10], [10, 20], 1, 'Exactly at boundaries'),
        # Additional test case: overlapping that should fail
        (3, 5, [0, 2, 4], [5, 7, 9], 0, 'Three tasks, insufficient time'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, t, a_list, b_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: {description}')
        
        try:
            # Write n and t
            if has_signal(dut, 'n'):
                dut.n.value = n
            else:
                raise TestFailure('Module missing n port')
            
            if has_signal(dut, 't'):
                dut.t.value = t
            else:
                raise TestFailure('Module missing t port')
            
            # Pack a and b into 16-bit values: {b, a}
            packed_values = []
            for a_val, b_val in zip(a_list, b_list):
                # Ensure a and b fit within DATA_WIDTH
                a_clamped = clamp_to_width(a_val, DATA_WIDTH)
                b_clamped = clamp_to_width(b_val, DATA_WIDTH)
                packed = (b_clamped << DATA_WIDTH) | a_clamped
                packed_values.append(packed)
            
            # Pad remaining array elements if n < ARRAY_SIZE
            while len(packed_values) < ARRAY_SIZE:
                packed_values.append(0)
            
            # Write to arr
            await write_packed_array(dut, packed_values, 16)
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure('Result is undefined (X/Z)')
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f'Expected {expected}, got {result}')
            
            cocotb.log.info(f'  PASS: result = {result}')
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
    
    # Summary
    cocotb.log.info(f'{"="*50}')
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')
