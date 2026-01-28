import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
NUM_TUPLES_MAX = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        # Handle signed values
        from_signed = value + (1 << bits) if value < 0 else value
        return min(max_val, max(0, from_signed))
    return min(max_val, max(0, value))

def string_to_byte_array(s, max_len=8):
    """Convert string to list of ASCII codes, padded to max_len."""
    bytes_list = [ord(c) for c in s[:max_len]]
    # Pad with zeros
    while len(bytes_list) < max_len:
        bytes_list.append(0)
    return bytes_list

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
async def test_find_minimum_tuple(dut):
    """Test finding tuple with minimum second value."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    # Format: (list_of_tuples, expected_first_value, description)
    # Tuples are (first_value, second_value) where first_value is encoded as ASCII byte
    test_cases = [
        # Test 1: [('Rash', 143), ('Manjeet', 200), ('Varsha', 100)]
        # Encoding: 'R'=82, 'M'=77, 'V'=86 (using first letter ASCII)
        # Expected: 'V' (86) with second value 100 (minimum)
        [
            (82, 143),  # 'Rash'
            (77, 200),  # 'Manjeet'
            (86, 100)   # 'Varsha'
        ],
        
        # Test 2: [('Yash', 185), ('Dawood', 125), ('Sanya', 175)]
        # Expected: 'D' (68) with second value 125
        [
            (89, 185),  # 'Yash'
            (68, 125),  # 'Dawood'
            (83, 175)   # 'Sanya'
        ],
        
        # Test 3: [('Sai', 345), ('Salman', 145), ('Ayesha', 96)]
        # Expected: 'A' (65) with second value 96
        [
            (83, 345),  # 'Sai'
            (83, 145),  # 'Salman'
            (65, 96)    # 'Ayesha'
        ],
    ]
    
    # Expected results (ASCII codes)
    expected_results = [86, 68, 65]
    
    passed = 0
    failed = 0
    
    for i, (tuples, expected) in enumerate(zip(test_cases, expected_results)):
        cocotb.log.info(f"Test {i+1}: Processing {len(tuples)} tuples")
        
        try:
            # Set number of tuples
            dut.num_tuples.value = len(tuples)
            
            # Set first and second values for each tuple
            for idx, (first_val, second_val) in enumerate(tuples):
                # Clamp values to 8-bit
                first_clamped = clamp_to_width(first_val, DATA_WIDTH)
                second_clamped = clamp_to_width(second_val, DATA_WIDTH)
                
                # Assign to ports
                if has_signal(dut, f'arr_first_{idx}'):
                    getattr(dut, f'arr_first_{idx}').value = first_clamped
                    getattr(dut, f'arr_second_{idx}').value = second_clamped
                else:
                    raise TestFailure(f"Missing port: arr_first_{idx}")
            
            # Zero out remaining ports
            for idx in range(len(tuples), NUM_TUPLES_MAX):
                if has_signal(dut, f'arr_first_{idx}'):
                    getattr(dut, f'arr_first_{idx}').value = 0
                    getattr(dut, f'arr_second_{idx}').value = 0
            
            # Wait a cycle for inputs to stabilize
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result_first.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result_first.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected} ({chr(expected)}), got {result} ({chr(result) if 32 <= result < 127 else '?'})")
            
            cocotb.log.info(f"  PASS: result = {result} ({chr(result)})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")