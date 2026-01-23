import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
FIXED_SHIFT = 24  # 24 fractional bits
ONE = 1 << FIXED_SHIFT
MAX_NODES = 8
MAX_L = 8

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return 0
    return min(max_val, value)

def reciprocal_float(value):
    """Compute fixed-point reciprocal from integer value 1-8"""
    if value == 1:
        return ONE
    elif value == 2:
        return ONE // 2
    elif value == 3:
        return ONE // 3
    elif value == 4:
        return ONE // 4
    elif value == 5:
        return ONE // 5
    elif value == 6:
        return ONE // 6
    elif value == 7:
        return ONE // 7
    elif value == 8:
        return ONE // 8
    else:
        return 0

def fixed_to_float(fixed_val):
    """Convert fixed-point to float"""
    return fixed_val / ONE

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_borg_sentry(dut):
    """Test the Borg Sentry probability computation module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            "N": 3,
            "L": 1,
            "walk": [0],
            "graph": [
                [2, [1, 2]],   # node 0: degree 2, neighbors 1,2
                [1, [0]],      # node 1: degree 1, neighbor 0
                [1, [0]]       # node 2: degree 1, neighbor 0
            ],
            "expected": 0.5
        },
        {
            "N": 8,
            "L": 6,
            "walk": [1, 0, 2, 3, 0, 1],
            "graph": [
                [7, [1,2,3,4,5,6,7]],  # node 0
                [1, [0]],                # node 1
                [2, [0,3]],              # node 2
                [2, [0,2]],              # node 3
                [1, [0]],                # node 4
                [1, [0]],                # node 5
                [1, [0]],                # node 6
                [1, [0]]                 # node 7
            ],
            "expected": 0.0446429
        },
        {
            "N": 8,
            "L": 7,
            "walk": [1, 0, 2, 3, 2, 0, 1],
            "graph": [
                [7, [1,2,3,4,5,6,7]],  # node 0
                [1, [0]],                # node 1
                [2, [0,3]],              # node 2
                [2, [0,2]],              # node 3
                [1, [0]],                # node 4
                [1, [0]],                # node 5
                [1, [0]],                # node 6
                [1, [0]]                 # node 7
            ],
            "expected": 0.177615
        }
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, test in enumerate(test_cases):
        dut._log.info(f"\nTest {test_idx+1}: N={test['N']}, L={test['L']}, walk={test['walk']}")
        
        # Load inputs
        dut.N.value = test['N']
        dut.L.value = test['L']
        
        # Set walk values (pad to 8 elements)
        walk_vals = test['walk'] + [0] * (MAX_L - len(test['walk']))
        for i in range(MAX_L):
            getattr(dut, f'walk{i}').value = walk_vals[i]
        
        # Set graph
        for node in range(test['N']):
            degree, neighbors = test['graph'][node]
            # Set degree
            getattr(dut, f'degree{node}').value = degree
            # Set neighbors (pad to 8)
            neighbor_vals = neighbors + [0] * (8 - len(neighbors))
            for i in range(8):
                getattr(dut, f'neighbors{node}_{i}').value = neighbor_vals[i]
        
        # Set unused nodes to degree 0
        for node in range(test['N'], MAX_NODES):
            getattr(dut, f'degree{node}').value = 0
            for i in range(8):
                getattr(dut, f'neighbors{node}_{i}').value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 1000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done in test {test_idx+1}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined in test {test_idx+1}")
        
        result_fixed = int(dut.result.value)
        result_float = fixed_to_float(result_fixed)
        
        # Compare with expected
        expected = test['expected']
        tolerance = 1e-6
        
        if abs(result_float - expected) <= tolerance:
            dut._log.info(f"  PASS: {result_float:.7f} (expected {expected:.7f})")
            passed += 1
        else:
            dut._log.error(f"  FAIL: {result_float:.7f} (expected {expected:.7f})")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")