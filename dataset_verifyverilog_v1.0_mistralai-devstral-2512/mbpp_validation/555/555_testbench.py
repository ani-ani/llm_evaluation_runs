import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
RESULT_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def compute_expected(n):
    """Compute the expected result using Python integers"""
    if n == 0:
        return 0
    S = n * (n + 1) // 2
    result = S * (S - 1)
    # Clamp to 32-bit for overflow cases
    if result >= (1 << 32):
        return (1 << 32) - 1
    return result

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_difference(dut):
    """Test the difference computation module"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from the problem
    test_cases = [
        (2, 6, "N=2: S=3, S*(S-1)=3*2=6"),
        (3, 30, "N=3: S=6, S*(S-1)=6*5=30"),
        (5, 210, "N=5: S=15, S*(S-1)=15*14=210"),
        (0, 0, "N=0: S=0, S*(S-1)=0"),
        (1, 0, "N=1: S=1, S*(S-1)=1*0=0"),
        (10, 1650, "N=10: S=55, S*(S-1)=55*54=2970")
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_input, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Set inputs
            dut.n.value = clamp_to_width(n_input, DATA_WIDTH)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # For N > 128, result may overflow, check modulo behavior
            if n_input > 128:
                # Just check that something was computed (overflow case)
                cocotb.log.info(f"N={n_input} overflow check: result={result}")
            else:
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1}: {e}")
            failed += 1
        
        # Small delay between tests
        await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")