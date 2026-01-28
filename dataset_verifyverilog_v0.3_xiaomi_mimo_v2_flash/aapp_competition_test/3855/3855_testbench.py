import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N_WIDTH = 30
ANS_WIDTH = 5
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPIED FROM TEMPLATE
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

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
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
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_packet_distribution(dut):
    """Test the packet_distribution module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Test cases: (input_n, expected_ans, description)
    test_cases = [
        (6, 3, "n=6"),
        (2, 2, "n=2"),
        (1, 1, "n=1"),
        (1000000000, 30, "n=1e9"),
        (1024, 11, "n=1024"),
        (1023, 10, "n=1023"),
        (1025, 11, "n=1025"),
        (3, 2, "n=3"),
        (8, 4, "n=8"),
        (536870911, 29, "n=536870911"),
        (10, 4, "n=10"),
        (15, 4, "n=15"),
        (16, 5, "n=16"),
        (17, 5, "n=17"),
        (1, 1, "n=1"),
        (0, 0, "n=0 (edge case)"),  # Problem states n>=1, but test anyway
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write input n
            if has_signal(dut, 'n'):
                # Clamp to N_WIDTH (30 bits)
                n_clamped = clamp_to_width(n_val, N_WIDTH)
                dut.n.value = n_clamped
            else:
                raise TestFailure("Input port 'n' not found")
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read output ans
            if not has_signal(dut, 'ans'):
                raise TestFailure("Output port 'ans' not found")
            
            if not is_value_defined(dut.ans.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.ans.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: ans = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")