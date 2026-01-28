import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 8  # Number of boxes in hardware implementation
WIDTH_ENERGY = 10
WIDTH_PROB = 16  # Q8.8 format
WIDTH_RESULT = 13
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# Q8.8 conversion: value = int(float * 256)
def to_q88(f):
    return int(f * 256)

def from_q88(val):
    return val / 256.0

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
async def test_find_polly(dut):
    """Main test for find_polly module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Test cases: (N, P_target, boxes: list of (energy, prob), expected_energy)
    test_cases = [
        {
            'N': 2,
            'P': 0.5,
            'boxes': [(2, 0.5), (1, 0.5)],
            'expected': 1
        },
        {
            'N': 2,
            'P': 0.5,
            'boxes': [(2, 0.51), (1, 0.49)],
            'expected': 2
        },
        {
            'N': 2,
            'P': 1.0,
            'boxes': [(2, 0.3291), (5, 0.6709)],
            'expected': 7
        },
        {
            'N': 2,
            'P': 1.0,
            'boxes': [(2, 0.3), (3, 0.3)],
            'expected': 5
        },
        {
            'N': 3,
            'P': 0.6,
            'boxes': [(10, 0.2), (5, 0.7), (3, 0.1)],
            'expected': 5
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={test['N']}, P={test['P']}")
        
        try:
            # Prepare inputs
            N_test = test['N']
            P_target_q88 = to_q88(test['P'])
            
            # Prepare energy and probability arrays (size N=8, pad with zeros)
            energies = [0] * N
            probs = [0] * N
            
            for j in range(N_test):
                e, p = test['boxes'][j]
                energies[j] = e
                probs[j] = to_q88(p)
            
            # Write inputs to DUT
            await write_array(dut, 'energy', energies, WIDTH_ENERGY)
            await write_array(dut, 'prob', probs, WIDTH_PROB)
            
            # Write P_target
            if has_signal(dut, 'P_target'):
                dut.P_target.value = P_target_q88
            else:
                raise TestFailure("Signal 'P_target' not found")
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.min_energy.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.min_energy.value)
            expected = test['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: min_energy = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
