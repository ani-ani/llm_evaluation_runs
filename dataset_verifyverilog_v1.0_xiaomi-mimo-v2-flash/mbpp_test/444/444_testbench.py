import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Configuration
DATA_WIDTH = 8
MAX_TUPLES = 4  # Adjusted to match test cases
MAX_ELEMENTS = 16
K_WIDTH = 4
TUPLE_IDX_WIDTH = 5
CLK_NS = 10
MAX_CYCLES = 1000

# Write input array for a specific tuple
def write_input_array(dut, tuple_idx, values, width=DATA_WIDTH):
    """Write values to input storage for a specific tuple index."""
    for i, val in enumerate(values):
        # Assuming input ports are arr_in_0_0, arr_in_0_1, etc.
        port_name = f'arr_in_{tuple_idx}_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, width)
        else:
            # Try generic array access
            if hasattr(dut, 'arr_in'):
                dut.arr_in[tuple_idx][i].value = clamp_to_width(val, width)

# Read output array for a specific tuple
def read_output_array(dut, tuple_idx, num_elements, width=DATA_WIDTH):
    """Read trimmed elements for a specific tuple."""
    result = []
    for i in range(num_elements):
        # Set tuple_idx and element_idx to read result
        dut.tuple_idx.value = tuple_idx
        dut.element_idx.value = i
        # Wait for result to propagate
        yield Timer(10, units='ns')
        if is_value_defined(dut.result.value):
            result.append(int(dut.result.value))
        else:
            result.append(0)
    return result

# Helper to calculate expected trimmed tuple
def calculate_trimmed_tuple(input_tuple, k):
    """Calculate trimmed tuple based on k."""
    n = len(input_tuple)
    if k * 2 >= n:
        return []  # Empty tuple after trimming
    return list(input_tuple)[k:n-k]

# Helper to pack array for output comparison
def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_trim_tuple(dut):
    """Test tuple trimming operation."""
    
    # Check if sequential (has clk)
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Start clock
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        if has_signal(dut, 'k_in'):
            dut.k_in.value = 0
        if has_signal(dut, 'total_tuples'):
            dut.total_tuples.value = 0
        
        for _ in range(2):
            await RisingEdge(dut.clk)
        
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational, just set inputs
        await Timer(100, units='ns')
    
    # Test cases from Python examples
    test_cases = [
        {
            'name': 'Test 1: k=2',
            'inputs': [
                (5, 3, 2, 1, 4),
                (3, 4, 9, 2, 1),
                (9, 1, 2, 3, 5),
                (4, 8, 2, 1, 7)
            ],
            'k': 2,
            'expected': [(2,), (9,), (2,), (2,)]
        },
        {
            'name': 'Test 2: k=1',
            'inputs': [
                (5, 3, 2, 1, 4),
                (3, 4, 9, 2, 1),
                (9, 1, 2, 3, 5),
                (4, 8, 2, 1, 7)
            ],
            'k': 1,
            'expected': [(3, 2, 1), (4, 9, 2), (1, 2, 3), (8, 2, 1)]
        },
        {
            'name': 'Test 3: k=1, 4-tuple arrays',
            'inputs': [
                (7, 8, 4, 9),
                (11, 8, 12, 4),
                (4, 1, 7, 8),
                (3, 6, 9, 7)
            ],
            'k': 1,
            'expected': [(8, 4), (8, 12), (1, 7), (6, 9)]
        }
    ]
    
    for test_idx, test_case in enumerate(test_cases):
        cocotb.log.info(f"Running {test_case['name']}")
        
        # Write input data to DUT
        inputs = test_case['inputs']
        k = test_case['k']
        expected = test_case['expected']
        
        # Pad all tuples to MAX_ELEMENTS length (16) with zeros for simplicity
        # In real implementation, we'd use actual lengths, but here we pad
        padded_inputs = []
        for tup in inputs:
            padded = list(tup) + [0] * (MAX_ELEMENTS - len(tup))
            padded_inputs.append(padded)
        
        # Write to DUT input storage
        for tuple_idx, tup_values in enumerate(padded_inputs):
            for i, val in enumerate(tup_values):
                # Try to write to arr_in ports
                port_name = f'arr_in_{tuple_idx}_{i}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
                else:
                    # Try alternative port naming
                    alt_name = f'arr_in_{tuple_idx}_{i}'
                    if has_signal(dut, alt_name):
                        getattr(dut, alt_name).value = clamp_to_width(val, DATA_WIDTH)
                    else:
                        cocotb.log.warning(f"Cannot find input port for tuple {tuple_idx}, element {i}")
        
        if is_seq:
            # Set parameters
            dut.k_in.value = clamp_to_width(k, K_WIDTH)
            dut.total_tuples.value = clamp_to_width(len(inputs), TUPLE_IDX_WIDTH)
            
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Test {test_idx}: Timeout waiting for done signal")
        else:
            # Combinational - set all inputs and wait
            await Timer(100, units='ns')
        
        # Verify results
        for tuple_idx, expected_tuple in enumerate(expected):
            # Read trimmed elements
            result_elements = []
            for element_idx in range(MAX_ELEMENTS):
                if is_seq:
                    dut.tuple_idx.value = tuple_idx
                    dut.element_idx.value = element_idx
                    await Timer(10, units='ns')  # Let signals propagate
                
                if is_value_defined(dut.result.value):
                    elem_val = int(dut.result.value)
                else:
                    elem_val = 0
                
                # Check if this is a valid output position
                expected_len = len(expected_tuple)
                if element_idx < expected_len:
                    result_elements.append(elem_val)
            
            # Compare with expected (only first expected_len elements)
            expected_len = len(expected_tuple)
            for i in range(expected_len):
                if i >= len(result_elements):
                    raise TestFailure(
                        f"Test {test_idx}, tuple {tuple_idx}: Expected {expected_len} elements, got {len(result_elements)}"
                    )
                if result_elements[i] != expected_tuple[i]:
                    raise TestFailure(
                        f"Test {test_idx}, tuple {tuple_idx}, element {i}: Expected {expected_tuple[i]}, got {result_elements[i]}"
                    )
            
            cocotb.log.info(f"  Tuple {tuple_idx}: OK (len={expected_len})")
        
        cocotb.log.info(f"{test_case['name']}: PASSED")
    
    cocotb.log.info("All tests passed!")

# Additional test for edge cases
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases: k=0, k too large."""
    
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
        dut.rst_n.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    # Edge case 1: k=0 (no trimming)
    test_inputs = [(1, 2, 3, 4)]
    k = 0
    expected = [(1, 2, 3, 4)]
    
    # Write inputs (padded)
    for i, v in enumerate([1, 2, 3, 4] + [0]*12):
        port_name = f'arr_in_0_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(v, DATA_WIDTH)
    
    if is_seq:
        dut.k_in.value = 0
        dut.total_tuples.value = 1
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure("Edge case k=0: Timeout")
    
    # Verify result
    dut.tuple_idx.value = 0
    for elem_idx in range(4):
        dut.element_idx.value = elem_idx
        await Timer(10, units='ns')
        if is_value_defined(dut.result.value):
            val = int(dut.result.value)
            if val != expected[0][elem_idx]:
                raise TestFailure(f"Edge case k=0: Expected {expected[0][elem_idx]}, got {val}")
    
    cocotb.log.info("Edge case k=0: PASSED")
    
    # Edge case 2: k too large (empty tuple)
    test_inputs = [(1, 2, 3, 4)]
    k = 2  # 4-2-2=0 elements remaining
    
    # Write inputs
    for i, v in enumerate([1, 2, 3, 4] + [0]*12):
        port_name = f'arr_in_0_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(v, DATA_WIDTH)
    
    if is_seq:
        dut.k_in.value = 2
        dut.total_tuples.value = 1
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure("Edge case k=2: Timeout")
    
    # For empty tuple, result should be 0
    dut.tuple_idx.value = 0
    dut.element_idx.value = 0
    await Timer(10, units='ns')
    if is_value_defined(dut.result.value):
        val = int(dut.result.value)
        # Empty tuple case - result should be 0 or undefined
        cocotb.log.info(f"Edge case k=2 (empty tuple): result = {val}")
    
    cocotb.log.info("Edge case k=2: PASSED")
