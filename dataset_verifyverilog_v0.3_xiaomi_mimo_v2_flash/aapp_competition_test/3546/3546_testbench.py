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
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 8
MAX_N = 8
MAX_PROOFS = 4
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000  # Increased due to DP complexity

# ============================================================================
# ARRAY ASSIGNMENT HELPERS (Critical for cocotb)
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            # For 2D array, arr[i] is a sub-array
            if isinstance(arr[i], list) or hasattr(arr[i], '__len__'):
                for j, v in enumerate(val):
                    arr[i][j].value = clamp_to_width(v, element_width)
            else:
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
async def test_shortest_article(dut):
    """Test the shortest_article module with the first sample input."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Configure the DUT with the first sample input
    n = 2
    dut.n.value = n
    
    # Theorem 0: 2 proofs
    num_proofs_0 = 2
    # We need to write to num_proofs array - assume it's 8-element array
    for i in range(MAX_N):
        if i == 0:
            dut.num_proofs[i].value = num_proofs_0
        else:
            dut.num_proofs[i].value = 0  # Not used
    
    # Proof lengths and dependencies
    # For theorem 0:
    #   Proof 0: len=10, dep=0
    #   Proof 1: len=3, dep=1<<1 = 2
    # For theorem 1:
    #   Proof 0: len=4, dep=1<<0 = 1
    
    # Initialize all proofs to 0 first
    for i in range(MAX_N):
        for j in range(MAX_PROOFS):
            dut.proof_len[i][j].value = 0
            dut.proof_dep[i][j].value = 0
    
    # Set actual values
    dut.proof_len[0][0].value = 10
    dut.proof_dep[0][0].value = 0
    dut.proof_len[0][1].value = 3
    dut.proof_dep[0][1].value = (1 << 1)  # 2
    
    dut.proof_len[1][0].value = 4
    dut.proof_dep[1][0].value = (1 << 0)  # 1
    
    # Wait a few cycles for signals to stabilize
    await Timer(100, units='ns')
    
    # Start computation
    await start_computation(dut)
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    result = int(dut.result.value)
    expected = 10
    
    dut._log.info(f"Computed result: {result}, Expected: {expected}")
    
    if result != expected:
        raise TestFailure(f"Result mismatch: expected {expected}, got {result}")
    
    dut._log.info("Test PASSED")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_shortest_article_second(dut):
    """Test the second sample input (n=4)."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Configure second sample input
    n = 4
    dut.n.value = n
    
    # Theorem 0: 2 proofs
    #   Proof 0: len=1, dep=[1,3] -> mask bits 1 and 3 -> 0b1010 = 10
    #   Proof 1: len=5, dep=[2] -> mask bit 2 -> 0b0100 = 4
    # Theorem 1: 1 proof
    #   Proof 0: len=2, dep=[] -> 0
    # Theorem 2: 1 proof
    #   Proof 0: len=0, dep=[] -> 0
    # Theorem 3: 2 proofs
    #   Proof 0: len=2, dep=[] -> 0
    #   Proof 1: len=1, dep=[1] -> 0b0010 = 2
    
    # Expected answer: 4
    
    # Initialize all proofs to 0
    for i in range(MAX_N):
        for j in range(MAX_PROOFS):
            dut.proof_len[i][j].value = 0
            dut.proof_dep[i][j].value = 0
            dut.num_proofs[i].value = 0
    
    # Set num_proofs
    dut.num_proofs[0].value = 2
    dut.num_proofs[1].value = 1
    dut.num_proofs[2].value = 1
    dut.num_proofs[3].value = 2
    
    # Set proofs for theorem 0
    dut.proof_len[0][0].value = 1
    dut.proof_dep[0][0].value = (1 << 1) | (1 << 3)  # bits 1 and 3 set: 0b1010 = 10
    dut.proof_len[0][1].value = 5
    dut.proof_dep[0][1].value = (1 << 2)  # 0b0100 = 4
    
    # Theorem 1
    dut.proof_len[1][0].value = 2
    dut.proof_dep[1][0].value = 0
    
    # Theorem 2
    dut.proof_len[2][0].value = 0
    dut.proof_dep[2][0].value = 0
    
    # Theorem 3
    dut.proof_len[3][0].value = 2
    dut.proof_dep[3][0].value = 0
    dut.proof_len[3][1].value = 1
    dut.proof_dep[3][1].value = (1 << 1)  # 0b0010 = 2
    
    await Timer(100, units='ns')
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    expected = 4
    
    dut._log.info(f"Computed result: {result}, Expected: {expected}")
    
    if result != expected:
        raise TestFailure(f"Result mismatch: expected {expected}, got {result}")
    
    dut._log.info("Test PASSED")
