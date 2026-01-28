import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TEST CONFIGURATION
# ============================================================================
SCALE = 1 << 16  # 65536
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# TEST CASES
# ============================================================================
test_cases = [
    # Test case 1: feasible, safety factor 20.0
    {
        "N": 2,
        "M": 2,
        "R": 100,
        "car_lane": [0, 1, 0, 0, 0, 0, 0, 0],
        "car_len": [10, 10, 0, 0, 0, 0, 0, 0],
        "car_pos": [10, 30, 0, 0, 0, 0, 0, 0],
        "expected_impossible": 0,
        "expected_safety_factor": int(20.0 * SCALE)  # 1310720
    },
    # Test case 2: impossible
    {
        "N": 2,
        "M": 2,
        "R": 100,
        "car_lane": [0, 1, 0, 0, 0, 0, 0, 0],
        "car_len": [10, 100, 0, 0, 0, 0, 0, 0],
        "car_pos": [10, 0, 0, 0, 0, 0, 0, 0],
        "expected_impossible": 1,
        "expected_safety_factor": 0
    }
]

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_autonomous_car(dut):
    """Test the autonomous car module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}: {tc['N']} lanes, {tc['M']} cars")
        
        # Set inputs
        dut.N.value = tc["N"]
        dut.M.value = tc["M"]
        dut.R.value = tc["R"]
        
        # Set car arrays element-wise
        for idx in range(8):
            # Check if the DUT has individual array elements
            if has_signal(dut, f'car_lane_{idx}'):
                getattr(dut, f'car_lane_{idx}').value = tc["car_lane"][idx]
                getattr(dut, f'car_len_{idx}').value = tc["car_len"][idx]
                getattr(dut, f'car_pos_{idx}').value = tc["car_pos"][idx]
            else:
                # Fallback to indexed array access
                if has_signal(dut, 'car_lane'):
                    dut.car_lane[idx].value = tc["car_lane"][idx]
                if has_signal(dut, 'car_len'):
                    dut.car_len[idx].value = tc["car_len"][idx]
                if has_signal(dut, 'car_pos'):
                    dut.car_pos[idx].value = tc["car_pos"][idx]
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for result_valid
        cycles = 0
        while not (is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for result_valid in test case {i+1}")
        
        # Read results
        if not is_value_defined(dut.result_impossible.value):
            raise TestFailure(f"Result_impossible is undefined in test case {i+1}")
        
        impossible = int(dut.result_impossible.value)
        safety_factor = int(dut.result_safety_factor.value)
        
        # Compare with expected
        if impossible != tc["expected_impossible"]:
            dut._log.error(f"Test {i+1} FAILED: expected impossible={tc['expected_impossible']}, got {impossible}")
            failed += 1
        else:
            if impossible == 0:
                if safety_factor != tc["expected_safety_factor"]:
                    dut._log.error(f"Test {i+1} FAILED: expected safety_factor={tc['expected_safety_factor']}, got {safety_factor}")
                    failed += 1
                else:
                    dut._log.info(f"Test {i+1} PASSED: safety_factor={safety_factor} (scaled)")
                    passed += 1
            else:
                dut._log.info(f"Test {i+1} PASSED: impossible=1")
                passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")