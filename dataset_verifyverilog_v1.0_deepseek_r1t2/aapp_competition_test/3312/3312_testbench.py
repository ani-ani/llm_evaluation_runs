import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 4
ARRAY_SIZE = 8
RESULT_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
GRID_SIZE = 4
MAX_ENERGY = 10
MAX_TIME = 20

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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_oil_cans(dut):
    """Test the oil_cans module with scaled-down problem instances."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # Case 1: 3x3 grid, start (0,0) energy 1, 2 cans
        {
            'start_energy': 1,
            'start_x': 0,
            'start_y': 0,
            'cans': [
                {'x': 1, 'y': 2, 't': 2, 'valid': 1},
                {'x': 1, 'y': 1, 't': 1, 'valid': 1},
            ],
            'expected': 0,
            'description': 'Sample 1: Cannot reach cans'
        },
        # Case 2: 3x3 grid, start (1,1) energy 1, 8 cans
        {
            'start_energy': 1,
            'start_x': 1,
            'start_y': 1,
            'cans': [
                {'x': 0, 'y': 1, 't': 1, 'valid': 1},
                {'x': 1, 'y': 0, 't': 1, 'valid': 1},
                {'x': 2, 'y': 1, 't': 1, 'valid': 1},
                {'x': 1, 'y': 2, 't': 1, 'valid': 1},
                {'x': 1, 'y': 2, 't': 2, 'valid': 1},
                {'x': 2, 'y': 2, 't': 3, 'valid': 1},
                {'x': 0, 'y': 2, 't': 5, 'valid': 1},
                {'x': 1, 'y': 2, 't': 6, 'valid': 1},
            ],
            'expected': 4,
            'description': 'Sample 2: Should collect 4 cans'
        },
        # Case 3: 3x3 grid, start (0,0) energy 1, 1 can at time 10
        {
            'start_energy': 1,
            'start_x': 0,
            'start_y': 0,
            'cans': [
                {'x': 1, 'y': 0, 't': 10, 'valid': 1},
            ],
            'expected': 1,
            'description': 'Modified Sample 3: Can at time 10'
        }
    ]
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        dut._log.info(f"Running test: {test['description']}")
        
        # Set starting parameters
        dut.start_energy.value = test['start_energy']
        dut.start_x.value = test['start_x']
        dut.start_y.value = test['start_y']
        
        # Set can events (8 events)
        can_signals = [
            ('can_x0', 'can_y0', 'can_t0', 'can_valid0'),
            ('can_x1', 'can_y1', 'can_t1', 'can_valid1'),
            ('can_x2', 'can_y2', 'can_t2', 'can_valid2'),
            ('can_x3', 'can_y3', 'can_t3', 'can_valid3'),
            ('can_x4', 'can_y4', 'can_t4', 'can_valid4'),
            ('can_x5', 'can_y5', 'can_t5', 'can_valid5'),
            ('can_x6', 'can_y6', 'can_t6', 'can_valid6'),
            ('can_x7', 'can_y7', 'can_t7', 'can_valid7'),
        ]
        
        # Initialize all cans as invalid
        for i in range(8):
            x_sig, y_sig, t_sig, valid_sig = can_signals[i]
            getattr(dut, x_sig).value = 0
            getattr(dut, y_sig).value = 0
            getattr(dut, t_sig).value = 0
            getattr(dut, valid_sig).value = 0
        
        # Set valid cans
        for i, can in enumerate(test['cans']):
            if i < 8:
                x_sig, y_sig, t_sig, valid_sig = can_signals[i]
                getattr(dut, x_sig).value = can['x']
                getattr(dut, y_sig).value = can['y']
                getattr(dut, t_sig).value = can['t']
                getattr(dut, valid_sig).value = can['valid']
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=10000)
            
            # Read result
            if is_value_defined(dut.max_points.value):
                result = int(dut.max_points.value)
                expected = test['expected']
                
                if result == expected:
                    dut._log.info(f"  PASS: got {result}, expected {expected}")
                    passed += 1
                else:
                    dut._log.error(f"  FAIL: got {result}, expected {expected}")
                    failed += 1
            else:
                dut._log.error("  FAIL: max_points is undefined")
                failed += 1
                
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
