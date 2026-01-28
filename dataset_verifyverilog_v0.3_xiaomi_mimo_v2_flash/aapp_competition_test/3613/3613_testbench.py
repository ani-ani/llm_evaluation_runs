import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY WRITE/READ HELPERS (for different interface styles)
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling 2D or individual ports."""
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
    """Read array values, handling 2D or individual ports."""
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

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Active‑low reset sequence."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_find_min_T(dut):
    """Test the find_min_T module with the provided sample."""
    
    # Configuration – must match module parameters
    N = 6
    DATA_WIDTH = 2      # teacher width
    PREF_WIDTH = 3      # kid index width (0‑5)
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case from the problem statement (converted to 0‑indexed)
    # Original input:
    # 6
    # 0 2 3 4 5 6
    # 0 1 3 4 5 6
    # 1 6 5 4 2 1
    # 2 6 5 3 2 1
    # 1 1 2 3 4 6
    # 2 1 2 3 4 5
    # After converting kid IDs to 0‑indexed (subtract 1):
    teachers = [0, 0, 1, 2, 1, 2]          # original teachers
    prefs = [
        [1, 2, 3, 4, 5],   # kid0: 2,3,4,5,6 → 1,2,3,4,5
        [0, 2, 3, 4, 5],   # kid1: 1,3,4,5,6 → 0,2,3,4,5
        [5, 4, 3, 1, 0],   # kid2: 6,5,4,2,1 → 5,4,3,1,0
        [5, 4, 2, 1, 0],   # kid3: 6,5,3,2,1 → 5,4,2,1,0
        [0, 1, 2, 3, 5],   # kid4: 1,2,3,4,6 → 0,1,2,3,5
        [0, 1, 2, 3, 4]    # kid5: 1,2,3,4,5 → 0,1,2,3,4
    ]
    expected_T = 4
    
    # Write teachers
    for i in range(N):
        dut.teacher[i].value = teachers[i]
    
    # Write preference lists
    for i in range(N):
        for j in range(N-1):
            dut.pref[i][j].value = prefs[i][j]
    
    # Start computation
    await start_computation(dut)
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result T
    if not is_value_defined(dut.T.value):
        raise TestFailure("T output is undefined (X/Z)")
    
    T_val = int(dut.T.value)
    
    if T_val != expected_T:
        raise TestFailure(f"Expected T={expected_T}, got T={T_val}")
    
    dut._log.info(f"Test passed: T={T_val}")
