import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
N = 8
DATA_WIDTH = 2
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
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
async def test_voting_system(dut):
    """Test voting_system module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (input_string, expected_min_swaps, expected_impossible, description)
    test_cases = [
        # Example 1: length 8, answer 4
        ("12210020", 4, False, "Sample input 1"),
        # Example: all 1's, no tellers -> impossible
        ("11111111", 0, True, "All voters, no tellers"),
        # Example: trivial, already winning, 0 swaps
        ("102", 0, False, "Simple case with teller"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_swaps, expected_impossible, description) in enumerate(test_cases):
        # Ensure input_str length equals N
        if len(input_str) != N:
            # Pad or truncate
            if len(input_str) < N:
                input_str = input_str + '0' * (N - len(input_str))
            else:
                input_str = input_str[:N]
        
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_str}")
        
        try:
            # Write input array
            for j, ch in enumerate(input_str):
                if ch == '0':
                    val = 0
                elif ch == '1':
                    val = 1
                elif ch == '2':
                    val = 2
                else:
                    raise TestFailure(f"Invalid character {ch}")
                
                # Assign to dut.arr_j
                if has_signal(dut, f'arr_{j}'):
                    getattr(dut, f'arr_{j}').value = val
                else:
                    # Fallback to array index
                    dut.arr[j].value = val
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read outputs
            impossible = 0
            min_swaps = 0
            if has_signal(dut, 'impossible'):
                impossible = safe_int(dut.impossible.value)
            if has_signal(dut, 'min_swaps'):
                min_swaps = safe_int(dut.min_swaps.value)
            
            # Verify
            if impossible != (1 if expected_impossible else 0):
                raise TestFailure(f"Impossibly flag mismatch: expected {expected_impossible}, got {impossible}")
            
            if not expected_impossible and min_swaps != expected_swaps:
                raise TestFailure(f"Min swaps mismatch: expected {expected_swaps}, got {min_swaps}")
            
            cocotb.log.info(f"  PASS: impossible={impossible}, min_swaps={min_swaps}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
