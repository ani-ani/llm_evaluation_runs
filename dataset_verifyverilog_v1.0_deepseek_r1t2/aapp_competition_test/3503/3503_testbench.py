import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 4            # Maximum number of pairs
W = 8            # Width of input numbers (signed)
R_W = 16         # Width of result
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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

def clamp_to_signed_width(value, bits):
    """Clamp value to fit within signed bit width."""
    min_val = -(1 << (bits - 1))
    max_val = (1 << (bits - 1)) - 1
    return max(min_val, min(max_val, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array_signed(dut, array_name, values, element_width):
    """Write signed values to array, handling different interface styles."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            clamped = clamp_to_signed_width(val, element_width)
            arr[i].value = clamped
        return
    except (AttributeError, TypeError):
        pass
    
    for i, val in enumerate(values):
        port_name = f'{array_name}_{i}'
        if has_signal(dut, port_name):
            clamped = clamp_to_signed_width(val, element_width)
            getattr(dut, port_name).value = clamped
        else:
            raise TestFailure(f'Cannot find array port: {array_name}[{i}] or {port_name}')

async def read_array(dut, array_name, size, signed=False, element_width=8):
    """Read array values, handling different interface styles."""
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                val = int(arr[i].value)
                if signed:
                    val = to_signed(val, element_width)
                results.append(val)
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    for i in range(size):
        port_name = f'{array_name}_{i}'
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                val_int = int(val)
                if signed:
                    val_int = to_signed(val_int, element_width)
                results.append(val_int)
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
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# PYTHON SOLVER (brute-force for small n)
# ============================================================================

def python_solver(pairs):
    """
    Find a valid assignment of operators to pairs such that all results are distinct.
    pairs: list of (a, b)
    Returns (exists, op_list, result_list) where op_list uses codes 0=add,1=sub,2=mul
    """
    n = len(pairs)
    if n == 0:
        return True, [], []
    
    from itertools import product
    for ops in product([0,1,2], repeat=n):
        results = []
        for (a,b), op in zip(pairs, ops):
            if op == 0:
                res = a + b
            elif op == 1:
                res = a - b
            else:  # op == 2
                res = a * b
            results.append(res)
        if len(set(results)) == n:
            return True, list(ops), results
    return False, None, None

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_exam_problem(dut):
    """Main test for ExamProblem module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        ('Example 1', 4, [(1,5), (3,3), (4,5), (-1,-6)]),
        ('Example 2 (impossible)', 4, [(-4,2), (-4,2), (-4,2), (-4,2)]),
        ('Single pair', 1, [(10,20)]),
        ('Two zeros', 2, [(0,0), (0,0)]),
        ('Three pairs possible', 3, [(1,2), (2,3), (3,4)]),
    ]
    
    total_passed = 0
    total_failed = 0
    
    for test_name, n, pairs in test_cases:
        dut._log.info(f'--- Test: {test_name} (n={n}) ---')
        
        # Prepare inputs: for i >= n, set a and b to 0
        a_vals = [pairs[i][0] if i < n else 0 for i in range(N)]
        b_vals = [pairs[i][1] if i < n else 0 for i in range(N)]
        
        # Write n
        if has_signal(dut, 'n'):
            dut.n.value = n
        else:
            raise TestFailure("Module missing 'n' input")
        
        # Write a and b arrays
        await write_array_signed(dut, 'a', a_vals, W)
        await write_array_signed(dut, 'b', b_vals, W)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check valid
        if not is_value_defined(dut.valid.value):
            raise TestFailure("valid signal undefined")
        
        valid = int(dut.valid.value)
        
        # Get Python expected
        exists, expected_ops, expected_results = python_solver(pairs)
        
        if valid == 1:
            # Solution found
            if not exists:
                raise TestFailure('Module found solution but Python says impossible')
            
            # Read op and result arrays
            op_vals = await read_array(dut, 'op', N, signed=False, element_width=2)
            result_vals = await read_array(dut, 'result', N, signed=True, element_width=R_W)
            
            # Verify first n entries
            # 1. Check op codes are among 0,1,2
            for i in range(n):
                if op_vals[i] is None:
                    raise TestFailure(f'op[{i}] undefined')
                if op_vals[i] not in [0,1,2]:
                    raise TestFailure(f'op[{i}] invalid value {op_vals[i]}')
            
            # 2. Check that each result equals a op b
            for i in range(n):
                a = pairs[i][0]
                b = pairs[i][1]
                op = op_vals[i]
                if op == 0:
                    expected = a + b
                elif op == 1:
                    expected = a - b
                else:
                    expected = a * b
                if result_vals[i] is None:
                    raise TestFailure(f'result[{i}] undefined')
                if result_vals[i] != expected:
                    raise TestFailure(f'Pair {i}: expected {expected}, got {result_vals[i]}')
            
            # 3. Check distinctness
            results_n = [result_vals[i] for i in range(n)]
            if len(set(results_n)) != n:
                raise TestFailure(f'Results not distinct: {results_n}')
            
            dut._log.info(f'  PASS: Valid solution with ops {op_vals[:n]}, results {results_n}')
            total_passed += 1
            
        else:  # valid == 0
            # Impossible
            if exists:
                raise TestFailure('Module says impossible but Python found a solution')
            dut._log.info(f'  PASS: Correctly reported impossible')
            total_passed += 1
    
    # Summary
    dut._log.info('=' * 50)
    dut._log.info(f'Results: {total_passed}/{total_passed+total_failed} tests passed')
    
    if total_failed > 0:
        raise TestFailure(f'{total_failed} tests failed')
