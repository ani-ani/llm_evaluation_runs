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

async def write_pupil_data(dut, pupil_idx, height, sex, music_code, sport_code):
    """Write a single pupil's data into the appropriate input port."""
    # Pack data: [31:24] sport, [23:16] music, [15:4] height, [3] sex, [2:0] unused
    data = (sport_code << 24) | (music_code << 16) | (height << 4) | (sex << 3)
    port_name = f"arr_{pupil_idx}"
    if has_signal(dut, port_name):
        getattr(dut, port_name).value = data
    else:
        raise TestFailure(f"Signal {port_name} not found")

def pack_pupil_data(height, sex, music_code, sport_code):
    """Return packed 32-bit pupil data."""
    return (sport_code << 24) | (music_code << 16) | (height << 4) | (sex << 3)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=20000):
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
# STRING TO CODE MAPPING
# ============================================================================

def map_strings_to_codes(test_pupils):
    """
    Convert list of pupil data with strings to codes.
    Input: list of tuples (height, sex, music_str, sport_str)
    Output: list of tuples (height, sex, music_code, sport_code)
    """
    music_map = {}
    sport_map = {}
    music_counter = 1
    sport_counter = 1
    processed_pupils = []
    
    for height, sex, music_str, sport_str in test_pupils:
        # Map music style to code
        if music_str not in music_map:
            music_map[music_str] = music_counter
            music_counter += 1
        music_code = music_map[music_str]
        
        # Map sport to code
        if sport_str not in sport_map:
            sport_map[sport_str] = sport_counter
            sport_counter += 1
        sport_code = sport_map[sport_str]
        
        processed_pupils.append((height, sex, music_code, sport_code))
    
    return processed_pupils

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_excursion(dut):
    """Test the max_excursion module with the provided test cases."""
    
    # Configuration
    CLK_PERIOD_NS = 10
    N_PUPILS = 8  # Module is fixed to 8 pupils
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Define test cases as (input_string, expected_output)
    test_cases = [
        (
            "4\n35 M classicism programming\n0 M baroque skiing\n43 M baroque chess\n30 F baroque soccer\n",
            3
        ),
        (
            "8\n27 M romance programming\n194 F baroque programming\n67 M baroque ping-pong\n51 M classicism programming\n80 M classicism Paintball\n35 M baroque ping-pong\n39 F romance ping-pong\n110 M romance Paintball\n",
            7
        )
    ]
    
    for test_idx, (input_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nRunning Test Case {test_idx+1}")
        
        # Parse input string
        lines = input_str.strip().split('\n')
        num_pupils = int(lines[0])
        pupils_raw = []
        for i in range(1, num_pupils+1):
            parts = lines[i].split()
            height = int(parts[0])
            sex = 1 if parts[1] == 'F' else 0  # 1 for Female, 0 for Male
            music_str = parts[2]
            sport_str = parts[3]
            pupils_raw.append((height, sex, music_str, sport_str))
        
        # Map strings to codes
        pupils = map_strings_to_codes(pupils_raw)
        
        # Set valid mask (only first num_pupils are valid)
        valid_mask = (1 << num_pupils) - 1
        dut.valid.value = valid_mask
        
        # Write pupil data to the module
        # For missing pupils (if any), set data to 0 (will be ignored by valid mask)
        for i in range(N_PUPILS):
            if i < len(pupils):
                height, sex, music_code, sport_code = pupils[i]
                # Clamp height to 12 bits (max 4095)
                height = clamp_to_width(height, 12)
                # Write packed data
                data = pack_pupil_data(height, sex, music_code, sport_code)
                port_name = f"arr_{i}"
                getattr(dut, port_name).value = data
            else:
                # Set dummy data for unused pupils
                getattr(dut, f"arr_{i}").value = 0
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.max_size.value):
            raise TestFailure(f"Test {test_idx+1}: max_size is undefined (X/Z)")
        
        result = int(dut.max_size.value)
        
        # Verify result
        if result != expected:
            raise TestFailure(f"Test {test_idx+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {test_idx+1}: PASS (result = {result})")
        
        # Wait for a few cycles before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    cocotb.log.info("All tests passed!")
