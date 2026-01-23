import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
MAX_BITS = 16
LOG_MAX_BITS = 4
MOD = 1000000009
RESULT_WIDTH = 32
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
# PACKING HELPERS
# ============================================================================

def pack_bin_bits(binary_string, max_bits=MAX_BITS):
    """Pack binary string into integer with LSB at index 0.
    binary_string: e.g., '1001' (MSB first)
    Returns: packed integer and length.
    """
    s = binary_string.strip()
    length = len(s)
    # Reverse to get LSB first
    bits = list(s)[::-1]
    packed = 0
    for i, b in enumerate(bits):
        if i >= max_bits:
            break
        if b == '1':
            packed |= (1 << i)
    return packed, length

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_count_representations(dut):
    """Main test for count_representations module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (binary_string, expected_output)
    test_cases = [
        ("1001", 3),
        ("1111", 1),
        ("00000", 1),
    ]
    
    passed = 0
    failed = 0
    
    for i, (binary_string, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input '{binary_string}', Expected {expected}")
        
        try:
            # Pack binary string
            packed, length = pack_bin_bits(binary_string)
            
            # Assign inputs
            dut.bin_bits.value = packed
            dut.length.value = length
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# ADDITIONAL TEST CASES (optional)
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases like single bit, all zeros, etc."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Edge cases: (binary_string, expected)
    edge_cases = [
        ("0", 1),        # Zero has only one representation
        ("1", 1),        # One
        ("10", 1),       # Two (binary 10) -> only '10'? Actually 2 can also be '2' (digit 2) => representation: '10' (binary) and '2' (single digit). Wait: '2' in base2 with digit 2 is 2*2^0=2, so yes. So 2 has two representations: '10' and '2'. But our DP? Let's compute: binary '10' (LSB=0, MSB=1). Process LSB (0): dp0=1, dp1=1. Process MSB (1): dp0_new = dp0+dp1 = 1+1=2, dp1_new = dp1=1. Final dp0=2 => answer 2. So expected should be 2, not 1. But the example didn't provide this. We'll compute expected using Python or known result. Let's compute manually: 2 in binary is '10'. Representations: '10' (binary), '2' (single digit). So 2 representations. So we should adjust expected to 2. We'll compute using a Python function to be safe.
    ]
    
    # Compute expected using Python DP for verification
    def count_representations_python(binary_str):
        bits = list(binary_str.strip())
        bits = bits[::-1]  # reverse to LSB first
        dp0, dp1 = 1, 0
        for b in bits:
            if b == '0':
                dp0, dp1 = dp0, (dp0 + dp1) % MOD
            else:
                dp0, dp1 = (dp0 + dp1) % MOD, dp1
        return dp0
    
    for binary_string in ["0", "1", "10", "101", "11111111"]:
        expected = count_representations_python(binary_string)
        cocotb.log.info(f"Edge test: Input '{binary_string}', Expected {expected}")
        
        try:
            packed, length = pack_bin_bits(binary_string)
            dut.bin_bits.value = packed
            dut.length.value = length
            
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS")
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            raise
