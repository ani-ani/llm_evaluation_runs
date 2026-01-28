import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 18
NUM_PULSES = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pixel_activation(dut):
    """Test the pixel activation counter."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: each has vertical pulses, horizontal pulses, expected count
    test_cases = [
        # Example 1: Expected 2
        {
            'vertical': [
                {'t': 2, 'm': 4, 'a': 2, 'valid': 1},
                {'t': 11, 'm': 2, 'a': 3, 'valid': 1}
            ],
            'horizontal': [
                {'t': 1, 'm': 4, 'a': 1, 'valid': 1},
                {'t': 10, 'm': 2, 'a': 2, 'valid': 1}
            ],
            'expected': 2
        },
        # Example 2: Expected 4
        {
            'vertical': [
                {'t': 1, 'm': 10, 'a': 1, 'valid': 1},
                {'t': 5, 'm': 10, 'a': 3, 'valid': 1}
            ],
            'horizontal': [
                {'t': 1, 'm': 10, 'a': 1, 'valid': 1},
                {'t': 5, 'm': 10, 'a': 2, 'valid': 1}
            ],
            'expected': 4
        },
        # Example 3: Expected 5
        {
            'vertical': [
                {'t': 1, 'm': 3, 'a': 1, 'valid': 1},
                {'t': 1, 'm': 15, 'a': 2, 'valid': 1}
            ],
            'horizontal': [
                {'t': 4, 'm': 5, 'a': 1, 'valid': 1},
                {'t': 5, 'm': 5, 'a': 2, 'valid': 1},
                {'t': 6, 'm': 5, 'a': 3, 'valid': 1},
                {'t': 7, 'm': 5, 'a': 4, 'valid': 1},
                {'t': 8, 'm': 5, 'a': 5, 'valid': 1}
            ],
            'expected': 5
        },
        # Additional test: all invalid, should get 0
        {
            'vertical': [],
            'horizontal': [],
            'expected': 0
        },
        # Additional test: one vertical, one horizontal that don't overlap
        {
            'vertical': [{'t': 100, 'm': 1, 'a': 1, 'valid': 1}],
            'horizontal': [{'t': 1, 'm': 1, 'a': 1, 'valid': 1}],
            'expected': 0
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: {test['expected']} expected")
        
        # Initialize all pulses to invalid
        for idx in range(NUM_PULSES):
            if has_signal(dut, f'vertical_valid[{idx}]'):
                getattr(dut, f'vertical_valid[{idx}]').value = 0
            if has_signal(dut, f'horizontal_valid[{idx}]'):
                getattr(dut, f'horizontal_valid[{idx}]').value = 0
        
        # Set vertical pulses
        for idx, pulse in enumerate(test['vertical']):
            if idx < NUM_PULSES:
                if has_signal(dut, f'vertical_t[{idx}]'):
                    getattr(dut, f'vertical_t[{idx}]').value = from_signed(pulse['t'], DATA_WIDTH)
                if has_signal(dut, f'vertical_m[{idx}]'):
                    getattr(dut, f'vertical_m[{idx}]').value = pulse['m']
                if has_signal(dut, f'vertical_a[{idx}]'):
                    getattr(dut, f'vertical_a[{idx}]').value = pulse['a']
                if has_signal(dut, f'vertical_valid[{idx}]'):
                    getattr(dut, f'vertical_valid[{idx}]').value = pulse['valid']
        
        # Set horizontal pulses
        for idx, pulse in enumerate(test['horizontal']):
            if idx < NUM_PULSES:
                if has_signal(dut, f'horizontal_t[{idx}]'):
                    getattr(dut, f'horizontal_t[{idx}]').value = from_signed(pulse['t'], DATA_WIDTH)
                if has_signal(dut, f'horizontal_m[{idx}]'):
                    getattr(dut, f'horizontal_m[{idx}]').value = pulse['m']
                if has_signal(dut, f'horizontal_a[{idx}]'):
                    getattr(dut, f'horizontal_a[{idx}]').value = pulse['a']
                if has_signal(dut, f'horizontal_valid[{idx}]'):
                    getattr(dut, f'horizontal_valid[{idx}]').value = pulse['valid']
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.count.value):
            dut._log.error(f"  FAIL: count is undefined (X/Z)")
            failed += 1
            continue
            
        result = int(dut.count.value)
        expected = test['expected']
        
        if result != expected:
            dut._log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"  PASS: count = {result}")
            passed += 1
        
        # Wait for next cycle before next test
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
