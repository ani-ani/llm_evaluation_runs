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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_digit_freq_validator(dut):
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module requires clock for sequential operation")
    
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_num, expected_result, description)
    test_cases = [
        (1234, True, "All digits freq=1, digit>=1"),
        (51241, False, "Digit 1 appears 2 times (freq > 1)"),
        (321, True, "All digits freq=1, digit>=1"),
        (112233, True, "Digits 1,2,3 appear twice (freq=2<=digit)"),
        (11111, False, "Digit 1 appears 5 times (freq > 1)"),
        (0, False, "Digit 0 appears 1 time (freq=1 > 0)"),
        (10000, False, "Digit 0 appears 4 times (freq=4 > 0)"),
        (111, False, "Digit 1 appears 3 times (freq=3 > 1)"),
        (55555, True, "Digit 5 appears 5 times (freq=5 <= 5)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (num, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (Input: {num})")
        try:
            # Prepare input
            dut.num_in.value = clamp_to_width(num, 16)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result = bool(int(dut.result.value))
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            # Wait one cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")