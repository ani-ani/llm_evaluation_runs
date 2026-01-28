import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

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
# TEST FUNCTION
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_module(dut):
    """Test domino_cover module."""
    
    # Detect if sequential or combinational
    is_sequential = has_signal(dut, 'clk') or has_signal(dut, 'done')
    if is_sequential:
        if has_signal(dut, 'clk'):
            cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await Timer(20, units='ns')
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
    
    # Test cases: (description, inputs, expected)
    test_cases = [
        (
            "K=2, example board",
            {
                'cell_0_0': 0, 'cell_0_1': 4, 'cell_0_2': 1,
                'cell_1_0': 3, 'cell_1_1': 5, 'cell_1_2': 1,
                'K': 2
            },
            13
        ),
        (
            "K=3, full coverage",
            {
                'cell_0_0': 0, 'cell_0_1': 1, 'cell_0_2': 2,
                'cell_1_0': 3, 'cell_1_1': 4, 'cell_1_2': 5,
                'K': 3
            },
            15
        ),
        (
            "K=1, max single domino",
            {
                'cell_0_0': 0, 'cell_0_1': 1, 'cell_0_2': 2,
                'cell_1_0': 3, 'cell_1_1': 4, 'cell_1_2': 5,
                'K': 1
            },
            9
        ),
        (
            "K=0, no dominoes",
            {
                'cell_0_0': 5, 'cell_0_1': 6, 'cell_0_2': 7,
                'cell_1_0': 8, 'cell_1_1': 9, 'cell_1_2': 10,
                'K': 0
            },
            0
        ),
        (
            "K=2, negative numbers",
            {
                'cell_0_0': -1, 'cell_0_1': -2, 'cell_0_2': -3,
                'cell_1_0': -4, 'cell_1_1': -5, 'cell_1_2': -6,
                'K': 2
            },
            -3
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (desc, inputs, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Set inputs
        for signal_name, value in inputs.items():
            if has_signal(dut, signal_name):
                if 'cell' in signal_name:
                    # Clamp to 8-bit signed
                    if value < 0:
                        clamped = from_signed(value, DATA_WIDTH)
                    else:
                        clamped = clamp_to_width(value, DATA_WIDTH)
                    getattr(dut, signal_name).value = clamped
                else:  # K
                    getattr(dut, signal_name).value = value
            else:
                raise TestFailure(f"Signal {signal_name} not found in DUT")
        
        # Wait for combinational propagation
        await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result_val = int(dut.result.value)
        result_signed = to_signed(result_val, RESULT_WIDTH)
        
        if result_signed != expected:
            dut._log.error(f"  FAIL: expected {expected}, got {result_signed}")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {result_signed}")
            passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")