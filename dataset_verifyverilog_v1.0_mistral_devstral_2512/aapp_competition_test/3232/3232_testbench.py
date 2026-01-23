import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 8  # Fixed string length
ALPHABET = 26
DATA_WIDTH = 5
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
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
# STRING HELPER FUNCTIONS
# ============================================================================

def char_to_bits(c):
    """Convert character 'a'-'z' to 5-bit value 0-25."""
    return ord(c) - ord('a')

def bits_to_char(bits):
    """Convert 5-bit value 0-25 to character 'a'-'z'."""
    return chr(bits + ord('a'))

def pack_string(s):
    """Pack string into list of 5-bit values."""
    return [char_to_bits(c) for c in s]

def unpack_string(values):
    """Convert list of 5-bit values back to string."""
    return ''.join(bits_to_char(v) for v in values)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_rearrange(dut):
    """Test string rearrange module with adapted test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Adapted test cases for N=8
    # Format: (input_string, expected_impossible)
    test_cases = [
        ("tralalal", False),  # Should be possible
        ("zzzzzzzz", True),   # z=8, N/2=4, 8>4 -> impossible
        ("annorlun", False),  # From "annorlunda" shortened
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_impossible) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input '{input_str}' (N={len(input_str)})")
        
        # Verify input length matches N
        if len(input_str) != N:
            cocotb.log.error(f"Test case error: expected length {N}, got {len(input_str)}")
            failed += 1
            continue
        
        try:
            # Pack input string
            input_bits = pack_string(input_str)
            
            # Write input characters to DUT
            for idx in range(N):
                dut.char_in[idx].value = input_bits[idx]
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read impossible flag
            if not is_value_defined(dut.impossible.value):
                raise TestFailure("impossible signal is undefined")
            
            is_impossible = int(dut.impossible.value) == 1
            
            # Check if expectation matches
            if is_impossible != expected_impossible:
                raise TestFailure(
                    f"Expected impossible={expected_impossible}, got {is_impossible}"
                )
            
            if expected_impossible:
                cocotb.log.info(f"  PASS: Correctly identified as impossible")
            else:
                # Read output string
                output_bits = []
                for idx in range(N):
                    if not is_value_defined(dut.char_out[idx].value):
                        raise TestFailure(f"Output char {idx} is undefined")
                    output_bits.append(int(dut.char_out[idx].value))
                
                output_str = unpack_string(output_bits)
                
                # Verify it's a permutation of input
                if sorted(output_str) != sorted(input_str):
                    raise TestFailure(
                        f"Output '{output_str}' is not a permutation of input '{input_str}'"
                    )
                
                # Verify all substrings are different
                half = N // 2
                substrings = [output_str[i:i+half] for i in range(half+1)]
                if len(substrings) != len(set(substrings)):
                    raise TestFailure(
                        f"Output has duplicate substrings: {substrings}"
                    )
                
                cocotb.log.info(f"  PASS: Output '{output_str}' is valid")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")