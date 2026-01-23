import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 3      # 3 bits for values 1-8
ARRAY_SIZE = 8
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
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def is_single_cycle(perm):
    """Check if permutation forms a single cycle covering all nodes."""
    n = len(perm)
    if n == 0:
        return False
    
    # Follow cycle from node 0
    visited = set()
    current = 0
    for _ in range(n):
        visited.add(current)
        current = perm[current] - 1  # Convert to 0-indexed
        if current in visited and len(visited) < n:
            return False
    
    return len(visited) == n and current == 0

def compare_assignments(b1, b2, a):
    """Return True if b1 is better than b2 according to tie-breaking rule."""
    for i in range(len(a)):
        b1_matches = (b1[i] == a[i])
        b2_matches = (b2[i] == a[i])
        
        if b1_matches and not b2_matches:
            return True
        if not b1_matches and b2_matches:
            return False
        
        # Both match or both don't match
        if not b1_matches and not b2_matches:
            if b1[i] < b2[i]:
                return True
            if b1[i] > b2[i]:
                return False
    
    return False  # Equal

def find_best_assignment(a):
    """Find the best mentor assignment for given original mentors."""
    n = len(a)
    best = None
    
    # Generate all permutations of 1..n
    for perm in itertools.permutations(range(1, n+1)):
        # Check if it's a single cycle
        if not is_single_cycle(list(perm)):
            continue
        
        # Check if better than current best
        if best is None or compare_assignments(list(perm), best, a):
            best = list(perm)
    
    return best

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_mentor_assignment(dut):
    """Test MentorAssignment module with random small inputs."""
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Test cases: each is a tuple (input_a, description)
    # We'll generate random test cases and compute expected output in Python
    import random
    random.seed(42)
    
    test_cases = []
    
    # Generate 5 random test cases
    for test_num in range(5):
        n = 8
        # Generate random mentor assignment
        # Each person's mentor must be different from themselves
        a = list(range(1, n+1))
        random.shuffle(a)
        for i in range(n):
            if a[i] == i+1:
                # Change if self-mentor
                a[i] = ((i+1) % n) + 1
        
        # Compute expected
        expected = find_best_assignment(a)
        
        test_cases.append((a, expected, f"Random test {test_num+1}"))
    
    # Add manual test cases
    # Test 1: Sample Input 2 adapted to 8 nodes
    a1 = [3, 3, 1, 4, 5, 6, 7, 8]
    expected1 = find_best_assignment(a1)
    test_cases.append((a1, expected1, "Sample Input 2 (8-node version)"))
    
    # Test 2: Simple cycle already
    a2 = [2, 3, 4, 5, 6, 7, 8, 1]
    expected2 = find_best_assignment(a2)
    test_cases.append((a2, expected2, "Already optimal cycle"))
    
    passed = 0
    failed = 0
    
    for i, (a_input, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"Input a: {a_input}")
        cocotb.log.info(f"Expected b: {expected}")
        
        try:
            # Write inputs
            await write_array(dut, 'a', a_input, DATA_WIDTH)
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
                
                # Read output
                result = await read_array(dut, 'b', ARRAY_SIZE)
                
                # Verify all values are defined
                if any(v is None for v in result):
                    raise TestFailure(f"Output contains undefined values: {result}")
                
                # Verify it's a single cycle
                if not is_single_cycle(result):
                    raise TestFailure(f"Output {result} is not a single cycle")
                
                # Verify it's the expected best assignment
                if not compare_assignments(result, expected, a_input) and result != expected:
                    # If result is not better than expected and not equal, fail
                    if compare_assignments(expected, result, a_input):
                        raise TestFailure(f"Output {result} is not optimal, expected {expected}")
                
                # Verify it's better than all other valid cycles
                # (This is a strong check - we can skip for speed or keep for thoroughness)
                
                cocotb.log.info(f"  PASS: b = {result}")
                passed += 1
            else:
                # Combinational module
                await Timer(100, units='ns')
                result = await read_array(dut, 'b', ARRAY_SIZE)
                
                if any(v is None for v in result):
                    raise TestFailure(f"Output contains undefined values: {result}")
                
                if not is_single_cycle(result):
                    raise TestFailure(f"Output {result} is not a single cycle")
                
                if not compare_assignments(result, expected, a_input) and result != expected:
                    if compare_assignments(expected, result, a_input):
                        raise TestFailure(f"Output {result} is not optimal, expected {expected}")
                
                cocotb.log.info(f"  PASS: b = {result}")
                passed += 1
        
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"FINAL RESULTS: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")