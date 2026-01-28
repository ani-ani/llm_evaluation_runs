import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
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

CLK_NS = 10
MAX_CYCLES = 1000

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def test_rotation(dut, s_str, n_val, expected_count):
    """Test a single rotation case"""
    # Convert string to 8-bit value (MSB-first)
    s_val = 0
    for i, ch in enumerate(s_str):
        if ch == '1':
            s_val |= (1 << (7 - i))  # Position 0 goes to bit 7
    
    dut.s.value = clamp_to_width(s_val, 8)
    dut.n.value = clamp_to_width(n_val, 8)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut, MAX_CYCLES)
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.result.value)
    if result != expected_count:
        raise TestFailure(f"Expected {expected_count}, got {result} (s={s_str}, n={n_val})")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_odd_equivalent(dut):
    """Test the odd_equivalent module with rotation cases"""
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational circuit
        await Timer(100, units='ns')
        
    test_cases = [
        # (input_string, rotations, expected_ones)
        ("011001", 6, 3),  # Test 1
        ("11011", 5, 4),   # Test 2
        ("1010", 4, 2),    # Test 3
        ("00000000", 10, 0),  # Edge case: all zeros
        ("11111111", 8, 8),   # Edge case: all ones
        ("10101010", 0, 4),   # Zero rotations
        ("10000001", 7, 2),   # Rotations around
        ("11100110", 4, 5),   # Random test
    ]
    
    passed = 0
    failed = 0
    
    for i, (s_str, n_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: s=\"{s_str}\", n={n_val} (expected {expected})")
        try:
            await test_rotation(dut, s_str, n_val, expected)
            cocotb.log.info(f"  PASS")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"\nAll {passed} tests passed!")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_reset_and_idle(dut):
    """Test reset behavior and idle state"""
    if not has_signal(dut, 'clk'):
        return  # Skip for combinational
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Check reset values
    if has_signal(dut, 'done') and int(dut.done.value) != 0:
        raise TestFailure(f"done should be 0 after reset, got {int(dut.done.value)}")
    
    if has_signal(dut, 'result') and int(dut.result.value) != 0:
        raise TestFailure(f"result should be 0 after reset, got {int(dut.result.value)}")
    
    cocotb.log.info("Reset test passed")
