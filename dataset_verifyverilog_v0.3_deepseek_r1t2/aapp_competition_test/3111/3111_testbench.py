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
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_operation(dut, A, B):
    """Pulse start for one cycle and wait for done, return result."""
    dut.A.value = A
    dut.B.value = B
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    # Result is valid when done is high
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return int(dut.result.value)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_dial_game(dut):
    """Test the dial game module with multiple test cases."""
    
    # Constants
    DATA_WIDTH = 4      # 4 bits for digits 0-9
    RESULT_WIDTH = 7    # 7 bits for sum up to 72
    CLK_PERIOD_NS = 10
    N_DIALS = 8         # DUT has parameter N=8
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Initialize all dials to 0 (to avoid X)
    for i in range(N_DIALS):
        dut.dials[i].value = 0
    
    # Define test cases
    test_cases = [
        {
            "name": "Sample 1",
            "N": 4,
            "initial": "1234",
            "ops": [(1,4), (1,4), (1,4)],
            "expected": [10, 14, 18]
        },
        {
            "name": "Sample 2",
            "N": 4,
            "initial": "1234",
            "ops": [(1,1), (1,2), (1,3), (1,4)],
            "expected": [1, 4, 9, 16]
        },
        {
            "name": "Sample 3",
            "N": 7,
            "initial": "9081337",
            "ops": [(1,3), (3,7), (1,3), (3,7), (1,3)],
            "expected": [17, 23, 1, 19, 5]
        }
    ]
    
    total_passed = 0
    total_failed = 0
    
    for test in test_cases:
        dut._log.info(f"Running {test['name']} (N={test['N']})")
        
        # Initialize dials with initial configuration
        init_str = test['initial']
        for i, digit in enumerate(init_str):
            if i < N_DIALS:
                dut.dials[i].value = int(digit)
        
        # For safety, set remaining dials to 0
        for i in range(len(init_str), N_DIALS):
            dut.dials[i].value = 0
        
        # Wait one cycle to let values settle
        await RisingEdge(dut.clk)
        
        # Process each operation
        for op_idx, ((A, B), expected) in enumerate(zip(test['ops'], test['expected'])):
            dut._log.info(f"  Operation {op_idx+1}: A={A}, B={B} (expected sum={expected})")
            
            try:
                result = await start_operation(dut, A, B)
                
                if result != expected:
                    raise TestFailure(f"Operation {op_idx+1}: expected {expected}, got {result}")
                
                dut._log.info(f"  PASS: result = {result}")
                total_passed += 1
                
                # Also verify that dials were updated correctly (optional)
                # We could read back the dials and check, but not required for this test
                
            except TestFailure as e:
                dut._log.error(f"  FAIL: {e}")
                total_failed += 1
    
    # Summary
    dut._log.info("="*60)
    dut._log.info(f"Total: {total_passed} passed, {total_failed} failed")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} test(s) failed")