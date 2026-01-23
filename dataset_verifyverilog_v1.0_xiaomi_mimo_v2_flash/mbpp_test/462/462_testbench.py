import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 6
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# ASCII codes for element names (0-63 range)
ELEMENT_CODES = {
    'red': 0,
    'green': 1,
    'blue': 2,
    'white': 3,
    'black': 4,
    'orange': 5,
    'yellow': 6,
    'purple': 7,
}

# ============================================================================
# HELPER FUNCTIONS
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# REFERENCE FUNCTION (Python itertools.combinations)
# ============================================================================

def get_all_combinations(elements):
    """Generate all combinations in binary counting order."""
    n = len(elements)
    all_combs = []
    for mask in range(1 << n):
        combo = []
        for i in range(n):
            if mask & (1 << i):
                combo.append(elements[i])
        all_combs.append(combo)
    return all_combs

# ============================================================================
# TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_combinations(dut):
    """Test combinational generation of all subsets."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            'name': '4 elements',
            'elements': ['orange', 'red', 'green', 'blue'],
            'expected_count': 16
        },
        {
            'name': '6 elements',
            'elements': ['red', 'green', 'blue', 'white', 'black', 'orange'],
            'expected_count': 64
        },
        {
            'name': '4 elements 2',
            'elements': ['red', 'green', 'black', 'orange'],
            'expected_count': 16
        }
    ]
    
    for test_case in test_cases:
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test: {test_case['name']}")
        cocotb.log.info(f"Elements: {test_case['elements']}")
        
        # Get expected combinations in binary counting order
        expected_combs = get_all_combinations(test_case['elements'])
        
        # Prepare input array
        n = len(test_case['elements'])
        valid_mask = (1 << n) - 1  # All valid
        
        # Write inputs
        for i in range(ARRAY_SIZE):
            if i < n:
                code = ELEMENT_CODES[test_case['elements'][i]]
                dut.arr[i].value = code
            else:
                dut.arr[i].value = 0
        
        dut.valid_mask.value = valid_mask
        
        # Wait 2 cycles for reset propagation
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        # Read generated combinations
        generated_combs = []
        current_combo = []
        current_index = -1
        total_iterations = 0
        max_iterations = 1000
        
        while total_iterations < max_iterations:
            await RisingEdge(dut.clk)
            total_iterations += 1
            
            # Read outputs
            if not is_value_defined(dut.out_valid.value):
                continue
            
            if int(dut.out_valid.value) == 1:
                # Read element data
                if is_value_defined(dut.out_element.value):
                    element_code = int(dut.out_element.value)
                    
                    # Reverse lookup for logging
                    element_name = 'unknown'
                    for name, code in ELEMENT_CODES.items():
                        if code == element_code:
                            element_name = name
                            break
                    
                    # Read combo index
                    if is_value_defined(dut.out_data.value):
                        out_data = int(dut.out_data.value)
                        combo_idx = (out_data >> 8) & 0xF
                        elem_count = out_data & 0xFF
                        
                        if combo_idx != current_index:
                            # New combination starting
                            if current_combo:
                                generated_combs.append(current_combo)
                            current_combo = [element_name]
                            current_index = combo_idx
                        else:
                            current_combo.append(element_name)
                        
                        cocotb.log.info(f"  Cycle {total_iterations}: combo_idx={combo_idx}, elem={element_name}")
            
            # Check if done
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                if current_combo:
                    generated_combs.append(current_combo)
                cocotb.log.info(f"Done asserted after {total_iterations} cycles")
                break
        
        # Verify results
        cocotb.log.info(f"\nVerifying {len(generated_combs)} combinations vs {len(expected_combs)} expected")
        
        if len(generated_combs) != len(expected_combs):
            raise TestFailure(f"Expected {len(expected_combs)} combinations, got {len(generated_combs)}")
        
        # Check each combination (order may vary due to element output order)
        for i, (expected, generated) in enumerate(zip(expected_combs, generated_combs)):
            # Sort both for comparison since output order might differ
            expected_sorted = sorted(expected)
            generated_sorted = sorted(generated)
            
            if expected_sorted != generated_sorted:
                raise TestFailure(f"Combination {i} mismatch: expected {expected}, got {generated}")
        
        cocotb.log.info(f"✓ All combinations verified correctly")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info("ALL TESTS PASSED")