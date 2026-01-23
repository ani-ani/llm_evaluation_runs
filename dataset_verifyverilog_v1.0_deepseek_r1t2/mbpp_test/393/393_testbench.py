import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_LISTS = 5
MAX_ELEMENTS = 8

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
    return min(max_val, max(0, value))

async def write_2d_array(dut, list_of_lists):
    """Write 2D array to DUT using individual port access."""
    # Pad to MAX_LISTS
    padded_lists = list_of_lists + [[]] * (MAX_LISTS - len(list_of_lists))
    
    for i, sublist in enumerate(padded_lists):
        # Pad sublist to MAX_ELEMENTS
        padded_sublist = sublist + [0] * (MAX_ELEMENTS - len(sublist))
        
        # Write each element
        for j, val in enumerate(padded_sublist):
            port_name = f'arr_{i}_{j}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        
        # Write length
        len_port = f'len_{i}'
        if has_signal(dut, len_port):
            actual_len = len(sublist)
            getattr(dut, len_port).value = clamp_to_width(actual_len, 3)
    
    # Write number of lists
    if has_signal(dut, 'num_lists'):
        dut.num_lists.value = len(list_of_lists)

async def read_result(dut):
    """Read max_length, max_index, and max_list from DUT."""
    max_length = int(dut.max_length.value) if is_value_defined(dut.max_length.value) else 0
    max_index = int(dut.max_index.value) if is_value_defined(dut.max_index.value) else 0
    
    max_list = []
    for j in range(MAX_ELEMENTS):
        port_name = f'max_list_{j}'
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                max_list.append(int(val))
            else:
                max_list.append(0)
        else:
            max_list.append(0)
    
    return max_length, max_index, max_list

# ============================================================================
# TESTS
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_max_length_list(dut):
    """Test the max_length_list module."""
    
    # Wait for combinational logic to settle
    await Timer(100, units='ns')
    
    # Test cases from problem
    test_cases = [
        {
            'name': 'Test 1: Mixed lengths',
            'input': [[0], [1, 3], [5, 7], [9, 11], [13, 15, 17]],
            'expected_length': 3,
            'expected_list': [13, 15, 17, 0, 0, 0, 0, 0],
            'expected_index': 4
        },
        {
            'name': 'Test 2: Decreasing lengths',
            'input': [[1,2,3,4,5],[1,2,3,4],[1,2,3],[1,2],[1]],
            'expected_length': 5,
            'expected_list': [1,2,3,4,5,0,0,0],
            'expected_index': 0
        },
        {
            'name': 'Test 3: Middle longest',
            'input': [[3,4,5],[6,7,8,9],[10,11,12]],
            'expected_length': 4,
            'expected_list': [6,7,8,9,0,0,0,0],
            'expected_index': 1
        }
    ]
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"Running {test['name']}")
        
        try:
            # Write inputs
            await write_2d_array(dut, test['input'])
            
            # Wait for propagation
            await Timer(100, units='ns')
            
            # Read outputs
            max_len, max_idx, max_list = await read_result(dut)
            
            # Verify max length
            if max_len != test['expected_length']:
                raise TestFailure(
                    f"Max length mismatch: expected {test['expected_length']}, got {max_len}"
                )
            
            # Verify max index (optional, but good for debugging)
            if max_idx != test['expected_index']:
                raise TestFailure(
                    f"Max index mismatch: expected {test['expected_index']}, got {max_idx}"
                )
            
            # Verify max list (first L elements should match, rest zero)
            L = test['expected_length']
            for i in range(L):
                if max_list[i] != test['expected_list'][i]:
                    raise TestFailure(
                        f"Max list element {i} mismatch: expected {test['expected_list'][i]}, got {max_list[i]}"
                    )
            for i in range(L, MAX_ELEMENTS):
                if max_list[i] != 0:
                    cocotb.log.warning(
                        f"Max list element {i} should be 0 but got {max_list[i]}"
                    )
            
            cocotb.log.info(f"  PASS: length={max_len}, list={max_list[:L]}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")