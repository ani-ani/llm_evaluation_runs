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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_file_deletion(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # Case 1: 3 delete, 2 keep (sample)
        {
            'nr': 80, 'nc': 50, 'n': 3, 'm': 2,
            'points': [
                (75, 5, 1), (25, 20, 1), (50, 35, 1),  # Delete
                (50, 5, 0), (25, 35, 0)                # Keep
            ],
            'expected': 2
        },
        # Case 2: 1 delete, 1 keep (no move)
        {
            'nr': 100, 'nc': 100, 'n': 1, 'm': 1,
            'points': [
                (50, 50, 1),  # Delete
                (80, 80, 0)   # Keep
            ],
            'expected': 0
        }
    ]
    
    for test in test_cases:
        dut._log.info(f"Testing: {test['n']} delete, {test['m']} keep")
        
        # Pack points into 232-bit vector
        packed = 0
        for idx, (r, c, is_delete) in enumerate(test['points']):
            # Compute center
            center_r = r + 7
            center_c = c + 4
            # Pack: type (1 bit) + x (14 bits) + y (14 bits)
            point_val = (is_delete << 28) | (center_r << 14) | center_c
            packed |= (point_val << (29 * idx))
        
        # Set inputs
        dut.nr.value = test['nr']
        dut.nc.value = test['nc']
        dut.N.value = test['n'] + test['m']
        dut.points_packed.value = packed
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.moves.value):
            raise TestFailure(f"Result is undefined")
        
        result = int(dut.moves.value)
        expected = test['expected']
        
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: moves = {result}")
        
        # Wait a few cycles between tests
        await Timer(100, units='ns')
        await reset_dut(dut)

    dut._log.info("All tests passed!")