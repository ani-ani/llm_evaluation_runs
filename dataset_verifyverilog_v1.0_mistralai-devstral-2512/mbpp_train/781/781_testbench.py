import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 300

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_divisor_count_even(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design - just set inputs
        await Timer(100, units='ns')
    
    test_cases = [
        (10, 1, "even divisors"),
        (100, 0, "odd divisors"),
        (125, 1, "even divisors"),
        (1, 1, "single divisor"),
        (2, 0, "prime number"),
        (16, 1, "perfect square even"),
    ]
    
    passed = failed = 0
    
    for i, (n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n} ({desc})")
        try:
            # Set input
            if is_seq:
                dut.n.value = clamp_to_width(n, DATA_WIDTH)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            else:
                # Combinational - just read
                await Timer(10, units='ns')
                if has_signal(dut, 'n'):
                    dut.n.value = clamp_to_width(n, DATA_WIDTH)
                    await Timer(10, units='ns')
                result = int(dut.result.value) if is_value_defined(dut.result.value) else 0
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    cocotb.log.info(f"All {passed} tests passed!")