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

async def wait_for_done(dut, max_cycles=10000):
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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_permutation_game(dut):
    """Main test function for permutation_game module."""
    
    # Start clock (10 ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Helper to convert 1-indexed to 0-indexed
    def to_zero_indexed(arr):
        return [x-1 for x in arr]
    
    # Define test cases: (n, k, q, s, expected)
    # q and s are 1-indexed from problem, converted to 0-indexed
    test_cases = [
        # Input 1: n=4,k=1,q=[2,3,4,1],s=[1,2,3,4] -> NO
        (4, 1, [2,3,4,1], [1,2,3,4], "NO"),
        # Input 2: n=4,k=1,q=[4,3,1,2],s=[3,4,2,1] -> YES
        (4, 1, [4,3,1,2], [3,4,2,1], "YES"),
        # Input 3: n=4,k=3,q=[4,3,1,2],s=[3,4,2,1] -> YES
        (4, 3, [4,3,1,2], [3,4,2,1], "YES"),
        # Input 4: n=4,k=2,q=[4,3,1,2],s=[2,1,4,3] -> YES
        (4, 2, [4,3,1,2], [2,1,4,3], "YES"),
        # Input 5: n=4,k=1,q=[4,3,1,2],s=[2,1,4,3] -> NO
        (4, 1, [4,3,1,2], [2,1,4,3], "NO"),
        # Input 6: n=4,k=3,q=[4,3,1,2],s=[2,1,4,3] -> NO (from provided list)
        (4, 3, [4,3,1,2], [2,1,4,3], "NO"),
        # Input 7: n=4,k=3,q=[2,1,4,3],s=[4,3,1,2] -> NO
        (4, 3, [2,1,4,3], [4,3,1,2], "NO"),
        # Input 8: n=4,k=1,q=[2,1,4,3],s=[2,1,4,3] -> YES (identity? Wait: s equals q, but also identity? No, s=q, so should be YES? Provided output is YES)
        (4, 1, [2,1,4,3], [2,1,4,3], "YES"),
        # Input 9: n=4,k=2,q=[2,1,4,3],s=[2,1,4,3] -> NO
        (4, 2, [2,1,4,3], [2,1,4,3], "NO"),
        # Input 10: n=4,k=2,q=[2,3,4,1],s=[1,2,3,4] -> NO
        (4, 2, [2,3,4,1], [1,2,3,4], "NO"),
        # Input 11: n=5,k=3,q=[2,1,4,3,5],s=[2,1,4,3,5] -> NO
        (5, 3, [2,1,4,3,5], [2,1,4,3,5], "NO"),
        # Input 12: n=9,k=10,q=[2,3,1,5,6,7,8,9,4],s=[2,3,1,4,5,6,7,8,9] -> NO
        (9, 10, [2,3,1,5,6,7,8,9,4], [2,3,1,4,5,6,7,8,9], "NO"),
        # Input 13: n=8,k=10,q=[2,3,1,5,6,7,8,4],s=[2,3,1,4,5,6,7,8] -> YES
        (8, 10, [2,3,1,5,6,7,8,4], [2,3,1,4,5,6,7,8], "YES"),
        # Input 14: n=8,k=9,q=[2,3,1,5,6,7,8,4],s=[2,3,1,4,5,6,7,8] -> YES
        (8, 9, [2,3,1,5,6,7,8,4], [2,3,1,4,5,6,7,8], "YES"),
        # Input 15: n=10,k=10,q=[2,3,1,5,6,7,8,4,10,9],s=[2,3,1,4,5,6,7,8,10,9] -> NO
        (10, 10, [2,3,1,5,6,7,8,4,10,9], [2,3,1,4,5,6,7,8,10,9], "NO"),
        # Input 16: n=10,k=9,q=[2,3,1,5,6,7,8,4,10,9],s=[2,3,1,4,5,6,7,8,10,9] -> YES
        (10, 9, [2,3,1,5,6,7,8,4,10,9], [2,3,1,4,5,6,7,8,10,9], "YES"),
        # Input 17: n=10,k=100,q=[2,3,1,5,6,7,8,4,10,9],s=[2,3,1,4,5,6,7,8,10,9] -> NO
        (10, 100, [2,3,1,5,6,7,8,4,10,9], [2,3,1,4,5,6,7,8,10,9], "NO"),
        # Input 18: n=10,k=99,q=[2,3,1,5,6,7,8,4,10,9],s=[2,3,1,4,5,6,7,8,10,9] -> YES
        (10, 99, [2,3,1,5,6,7,8,4,10,9], [2,3,1,4,5,6,7,8,10,9], "YES"),
        # Input 19: n=9,k=100,q=[2,3,1,5,6,7,8,9,4],s=[2,3,1,4,5,6,7,8,9] -> NO
        (9, 100, [2,3,1,5,6,7,8,9,4], [2,3,1,4,5,6,7,8,9], "NO"),
        # Input 20: n=5,k=99,q=[2,1,4,3,5],s=[2,1,4,3,5] -> NO
        (5, 99, [2,1,4,3,5], [2,1,4,3,5], "NO"),
        # Input 21: n=5,k=1,q=[2,1,4,3,5],s=[2,1,4,3,5] -> YES
        (5, 1, [2,1,4,3,5], [2,1,4,3,5], "YES"),
    ]
    
    for i, (n, k, q_1indexed, s_1indexed, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest case {i+1}: n={n}, k={k}, expected={expected}")
        
        # Convert to 0-indexed
        q = to_zero_indexed(q_1indexed)
        s = to_zero_indexed(s_1indexed)
        
        # Set n and k
        dut.n.value = n
        dut.k.value = k
        
        # Set q and s arrays (only first n elements matter)
        for idx in range(100):
            if idx < n:
                dut.q[idx].value = q[idx]
                dut.s[idx].value = s[idx]
            else:
                dut.q[idx].value = 0
                dut.s[idx].value = 0
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.yes.value):
            raise TestFailure(f"Test {i+1}: Output yes is undefined")
        
        result = "YES" if int(dut.yes.value) == 1 else "NO"
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result}")
        
        # Reset before next test
        await reset_dut(dut)
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"All {len(test_cases)} tests passed!")
