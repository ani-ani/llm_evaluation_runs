import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 1          # Each character is 1 bit
MAX_STRINGS = 8
MAX_STR_LEN = 8
MAX_RESULT_LEN = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000       # Timeout for computation

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
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
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.config_mode.value = 0
    dut.config_done.value = 0
    dut.start.value = 0
    # Clear string inputs
    for i in range(MAX_STRINGS):
        if has_signal(dut, f'str_len_{i}'):
            getattr(dut, f'str_len_{i}').value = 0
        if has_signal(dut, f'str_data_{i}'):
            getattr(dut, f'str_data_{i}').value = 0
    if has_signal(dut, 'num_strings'):
        dut.num_strings.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def configure_strings(dut, strings):
    """Configure the DUT with the given list of binary strings.
    strings: list of strings, e.g., ['00', '01', '10']
    """
    # Set config_mode high
    dut.config_mode.value = 1
    dut.num_strings.value = len(strings)
    
    # Set each string's length and data
    for i, s in enumerate(strings):
        # Length
        str_len = len(s)
        if has_signal(dut, f'str_len_{i}'):
            getattr(dut, f'str_len_{i}').value = str_len
        else:
            # Fallback to indexed array (if your HDL uses str_len[i])
            dut.str_len[i].value = str_len
        
        # Data: pack bits with LSB first, i.e., s[0] -> bit 0
        data_val = 0
        for j, char in enumerate(s):
            if char == '1':
                data_val |= (1 << j)  # j-th bit (LSB is first char)
        if has_signal(dut, f'str_data_{i}'):
            getattr(dut, f'str_data_{i}').value = data_val
        else:
            dut.str_data[i].value = data_val
    
    # Pulse config_done
    await RisingEdge(dut.clk)
    dut.config_done.value = 1
    await RisingEdge(dut.clk)
    dut.config_done.value = 0
    dut.config_mode.value = 0
    # Wait for configuration to finish (internal busy deasserts)
    # We'll assume configuration completes within 100 cycles
    for _ in range(100):
        if has_signal(dut, 'busy'):
            if not is_value_defined(dut.busy.value) or int(dut.busy.value) == 0:
                break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Configuration did not finish within 100 cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_result(dut):
    """Wait for result_valid or result_infinite, with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            return 'finite'
        if is_value_defined(dut.result_infinite.value) and int(dut.result_infinite.value) == 1:
            return 'infinite'
    raise TestFailure(f"Timeout: no result after {MAX_CYCLES} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_taboo_solver(dut):
    """Main test function for Taboo solver."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (list of taboo strings, expected output)
    # Expected output: ('infinite', None) for -1, ('finite', string) for finite answer
    test_cases = [
        (['00', '01', '10', '110', '111'], ('finite', '11')),
        (['00', '01', '10'], ('infinite', None)),
    ]
    
    for idx, (taboo_strings, expected) in enumerate(test_cases):
        dut._log.info(f"\nTest case {idx+1}: Taboo strings = {taboo_strings}")
        
        # Configure
        await configure_strings(dut, taboo_strings)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for result
        result_type = await wait_for_result(dut)
        
        if result_type == 'infinite':
            if expected[0] != 'infinite':
                raise TestFailure(f"Expected finite result, got infinite")
            dut._log.info(f"  PASS: Got infinite as expected")
        else:
            # Read result_string and result_length
            if not is_value_defined(dut.result_string.value):
                raise TestFailure("result_string is undefined (X/Z)")
            if not is_value_defined(dut.result_length.value):
                raise TestFailure("result_length is undefined (X/Z)")
            
            result_string_val = int(dut.result_string.value)
            result_length_val = int(dut.result_length.value)
            
            # Convert packed result to string
            result_str = ''
            for i in range(result_length_val):
                bit = (result_string_val >> i) & 1
                result_str += str(bit)
            
            if expected[0] != 'finite':
                raise TestFailure(f"Expected infinite result, got '{result_str}'")
            
            expected_str = expected[1]
            if result_str != expected_str:
                raise TestFailure(f"Expected '{expected_str}', got '{result_str}'")
            
            dut._log.info(f"  PASS: Got '{result_str}' as expected")
    
    dut._log.info("\nAll tests passed!")
