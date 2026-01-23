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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_insertions(dut):
    """Test the min_insertions module with multiple test cases."""
    
    # Configure based on your design
    DATA_WIDTH = 8
    ARRAY_SIZE = 8
    CLK_PERIOD_NS = 10
    
    # Start clock if sequential
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut, cycles=2)
    else:
        await Timer(100, units='ns')
    
    # Test cases: (N, K, sequence, expected_result)
    # Scaled to N<=8, K<=5
    test_cases = [
        (2, 5, [1, 1], 3),     # Original: 2 5 -> 1 1 -> output 3
        (5, 3, [2, 2, 3, 2, 2], 2),  # Original: 5 3 -> 2 2 3 2 2 -> output 2
        (3, 3, [1, 2, 1], 1),  # Small custom test
        (4, 3, [1, 2, 2, 1], 2),  # Another custom test
        (1, 2, [1], 1),        # Single marble, need 1 insertion
        (8, 4, [1,1,1,1,2,2,2,2], 0),  # Already vanishes
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, K, seq, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, K={K}, seq={seq}, expected={expected}")
        
        try:
            # Set N and K if they exist
            if has_signal(dut, 'N'):
                dut.N.value = N
            if has_signal(dut, 'K'):
                dut.K.value = K
            
            # Write array - pad to ARRAY_SIZE with zeros
            full_seq = seq + [0] * (ARRAY_SIZE - len(seq))
            if has_signal(dut, 'arr'):
                for idx, val in enumerate(full_seq):
                    dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
            else:
                # Try individual ports arr_0, arr_1, ...
                for idx, val in enumerate(full_seq):
                    port_name = f"arr_{idx}"
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
            
            # Start computation for sequential modules
            if has_signal(dut, 'start'):
                await start_computation(dut)
                await wait_for_done(dut, max_cycles=10000)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")