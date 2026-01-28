import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
N_WIDTH = 4
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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_list(dut, list_name, values, element_width=DATA_WIDTH, max_size=ARRAY_SIZE):
    """Write values to list using individual ports."""
    # Pad or truncate to max_size
    padded_values = values + [0] * (max_size - len(values))
    
    for i in range(max_size):
        port_name = f"{list_name}_{i}"
        if has_signal(dut, port_name):
            val = padded_values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find port: {port_name}")

async def read_products(dut, N, max_size=ARRAY_SIZE):
    """Read top N products from output ports."""
    results = []
    for i in range(min(N, max_size)):
        port_name = f"products_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
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
async def test_large_product(dut):
    """Test large_product module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases adapted for hardware
    # Original: nums1=[1,2,3,4,5,6], nums2=[3,6,8,9,10,6], N=3,4,5
    # Expected: [60,54,50], [60,54,50,48], [60,54,50,48,45]
    
    test_cases = [
        {
            'nums1': [1, 2, 3, 4, 5, 6],
            'nums2': [3, 6, 8, 9, 10, 6],
            'N': 3,
            'expected': [60, 54, 50],
            'description': 'N=3, nums1 size=6, nums2 size=6'
        },
        {
            'nums1': [1, 2, 3, 4, 5, 6],
            'nums2': [3, 6, 8, 9, 10, 6],
            'N': 4,
            'expected': [60, 54, 50, 48],
            'description': 'N=4, nums1 size=6, nums2 size=6'
        },
        {
            'nums1': [1, 2, 3, 4, 5, 6],
            'nums2': [3, 6, 8, 9, 10, 6],
            'N': 5,
            'expected': [60, 54, 50, 48, 45],
            'description': 'N=5, nums1 size=6, nums2 size=6'
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {tc['description']}")
        cocotb.log.info(f"nums1={tc['nums1']}")
        cocotb.log.info(f"nums2={tc['nums2']}")
        cocotb.log.info(f"N={tc['N']}")
        cocotb.log.info(f"Expected: {tc['expected']}")
        
        try:
            # Write inputs
            await write_list(dut, 'nums1', tc['nums1'])
            await write_list(dut, 'nums2', tc['nums2'])
            
            # Write N and lengths
            dut.N.value = tc['N']
            dut.len1.value = len(tc['nums1'])
            dut.len2.value = len(tc['nums2'])
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            results = await read_products(dut, tc['N'])
            
            # Filter out None values
            results = [r for r in results if r is not None]
            
            # Compare with expected
            if results != tc['expected']:
                raise TestFailure(f"Expected {tc['expected']}, got {results}")
            
            cocotb.log.info(f"  PASS: Got {results}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")