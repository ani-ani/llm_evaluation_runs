import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# Array write helper
async def write_board(dut, values):
    """Write 16 values to board_0..board_15."""
    for i in range(16):
        signal_name = f'board_{i}'
        if has_signal(dut, signal_name):
            getattr(dut, signal_name).value = clamp_to_width(values[i], 8)
        else:
            raise TestFailure(f"Signal {signal_name} not found")

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_magic_checkerboard(dut):
    """Test the magic_checkerboard module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        {
            "name": "Example 1",
            "input": [
                1, 2, 3, 0,
                0, 0, 5, 6,
                0, 0, 7, 8,
                7, 0, 0, 10
            ],
            "expected": 88
        },
        {
            "name": "Example 2 (invalid)",
            "input": [
                1, 2, 3, 0,
                0, 0, 5, 6,
                0, 4, 7, 8,
                7, 0, 0, 10
            ],
            "expected": -1
        }
    ]
    
    for tc in test_cases:
        dut._log.info(f"Running test: {tc['name']}")
        
        # Write input board
        await write_board(dut, tc['input'])
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
        
        result = int(dut.result.value)
        
        # Check result
        if tc['expected'] == -1:
            if result != 0xFFFF:
                raise TestFailure(f"Expected -1 (0xFFFF), got {result}")
        else:
            if result != tc['expected']:
                raise TestFailure(f"Expected {tc['expected']}, got {result}")
        
        dut._log.info(f"  Result: {result} [PASS]")
        
        # Reset for next test
        await reset_dut(dut)
    
    dut._log.info("All tests passed")