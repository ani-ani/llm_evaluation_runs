import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
    """Clamp value to fit within specified bit width."""
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
    """Pulse compute signal for one cycle."""
    dut.compute.value = 1
    await RisingEdge(dut.clk)
    dut.compute.value = 0

# ============================================================================
# INPUT PARSING
# ============================================================================

def parse_input(input_str):
    """Parse the input string and return n, game_description, expected_output."""
    lines = input_str.strip().split('\n')
    n = int(lines[0])
    
    game_desc = []
    for i in range(1, n+1):
        tokens = lines[i].split()
        m = int(tokens[0])
        options = []
        for j in range(1, m+1):
            options.append(tokens[j])
        game_desc.append(options)
    
    return n, game_desc

def parse_expected_output(output_str, n):
    """Parse expected output string into 2D list."""
    lines = output_str.strip().split('\n')
    expected = []
    for i in range(n):
        nums = list(map(int, lines[i].split()))
        expected.append(nums)
    return expected

def string_to_mask(s, n):
    """Convert position string (e.g., 'ab') to bitmask."""
    mask = 0
    for c in s:
        idx = ord(c) - ord('a')
        if idx < n:
            mask |= (1 << idx)
    return mask

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_game_solver(dut):
    """Test the game solver module."""
    
    # Test cases: input and expected output
    test_inputs = [
        "2\n2 ab b\n1 b\n",
        "3\n1 b\n2 b a\n2 ab ac\n"
    ]
    test_outputs = [
        "0 1 \n-1 0\n",
        "0 1 -1 \n1 0 -1 \n2 2 0"
    ]
    
    # Detect module parameters from DUT
    N = 8  # Default, will be overridden by parameter
    MAX_OPTIONS = 8
    
    # Check if DUT has parameters (simplified - assume default)
    # In real testbench, we would read parameters from DUT
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    for test_idx, (input_str, output_str) in enumerate(zip(test_inputs, test_outputs)):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test Case {test_idx+1}")
        dut._log.info(f"{'='*60}")
        
        # Parse input
        n, game_desc = parse_input(input_str)
        expected = parse_expected_output(output_str, n)
        
        dut._log.info(f"Input n={n}")
        
        # Load game description into DUT
        dut._log.info("Loading game description...")
        for pos in range(n):
            for opt_idx, option_str in enumerate(game_desc[pos]):
                mask = string_to_mask(option_str, n)
                dut._log.info(f"  pos={pos}, opt={opt_idx}, mask=0b{mask:0{n}b}")
                
                # Set load signals
                dut.load_pos.value = pos
                dut.load_option_idx.value = opt_idx
                dut.load_option_mask.value = mask
                dut.load_en.value = 1
                await RisingEdge(dut.clk)
                dut.load_en.value = 0
        
        dut._log.info("Loading complete.")
        
        # Compute distances for all start-target pairs
        dut._log.info("Computing distances...")
        
        results = [[None for _ in range(n)] for _ in range(n)]
        
        for start in range(n):
            for target in range(n):
                # Set target and start
                dut.target.value = target
                dut.start.value = start
                
                # Start computation
                await start_computation(dut)
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read distance
                if is_value_defined(dut.distance.value):
                    dist_val = int(dut.distance.value)
                    # Convert 0xF to -1
                    if dist_val == 0xF:
                        dist_val = -1
                    results[start][target] = dist_val
                else:
                    results[start][target] = -1
        
        # Compare results
        dut._log.info("Comparing results...")
        passed = True
        for start in range(n):
            for target in range(n):
                got = results[start][target]
                exp = expected[start][target]
                if got != exp:
                    dut._log.error(f"  Mismatch: start={start}, target={target}: expected {exp}, got {got}")
                    passed = False
                else:
                    dut._log.info(f"  start={start}, target={target}: {got} ✓")
        
        if not passed:
            raise TestFailure(f"Test case {test_idx+1} failed")
        
        dut._log.info(f"Test case {test_idx+1} passed.")
    
    dut._log.info("\nAll tests passed!")
