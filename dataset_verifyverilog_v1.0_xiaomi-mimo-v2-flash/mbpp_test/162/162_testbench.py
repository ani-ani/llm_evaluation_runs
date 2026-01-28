import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_sum_series(dut):
    # Check for required signals
    required_signals = ['clk', 'rst_n', 'start', 'n_in', 'result', 'done']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    # Setup clock and reset
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n_input, expected_result, description)
    test_cases = [
        (6, 12, "n=6: 6+4+2=12"),
        (10, 30, "n=10: 10+8+6+4+2=30"),
        (9, 25, "n=9: 9+7+5+3+1=25"),
        (1, 1, "n=1: 1=1"),
        (2, 2, "n=2: 2=2"),
        (0, 0, "n=0: 0=0"),
        (16, 72, "n=16: 16+14+...+2=72"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_in, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n_in={n_in})")
        try:
            # Set inputs
            dut.n_in.value = clamp_to_width(n_in, 8)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=35)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} - Result: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            
        # Brief delay between tests
        await Timer(100, units='ns')
    
    cocotb.log.info(f"\nSummary: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")