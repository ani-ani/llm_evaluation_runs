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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_sequence_counter(dut):
    # Check for required signals
    required_signals = ['clk', 'rst_n', 'start', 'm', 'n', 'result', 'done']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset function
    async def reset_dut(dut, cycles=2):
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.m.value = 0
        dut.n.value = 0
        for _ in range(cycles):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Wait for done with timeout
    async def wait_for_done(dut, max_cycles=256):
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        raise TestFailure(f"Timeout after {max_cycles} cycles waiting for done")
    
    # Test cases from problem
    test_cases = [
        (10, 4, 4, "Test 1: m=10, n=4"),
        (5, 2, 6, "Test 2: m=5, n=2"),
        (16, 3, 84, "Test 3: m=16, n=3")
    ]
    
    passed = 0
    failed = 0
    
    for m, n, expected, desc in test_cases:
        cocotb.log.info(f"Running: {desc}")
        try:
            # Reset DUT
            await reset_dut(dut)
            
            # Apply inputs
            dut.m.value = clamp_to_width(m, 4)
            dut.n.value = clamp_to_width(n, 4)
            
            # Assert start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for computation to complete
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: {desc} - Result {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")