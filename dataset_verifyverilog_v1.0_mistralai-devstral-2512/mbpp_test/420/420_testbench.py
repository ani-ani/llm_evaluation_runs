import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def cube_sum_expected(n):
    if n == 0: return 0
    total = 0
    for i in range(1, n + 1):
        total += (2*i) * (2*i) * (2*i)
    return total

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_cube_sum_even(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        (0, 0, "n=0"),
        (1, 8, "n=1"),
        (2, 72, "n=2"),
        (3, 288, "n=3"),
        (4, 800, "n=4"),
        (5, 1728, "n=5"),
        (10, 20000, "n=10"),
        (15, 405000, "n=15")
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            if is_seq:
                dut.n.value = n_val
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                await RisingEdge(dut.clk)
            else:
                dut.n.value = n_val
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            if is_seq and is_value_defined(dut.done.value):
                if int(dut.done.value) != 1:
                    raise TestFailure(f"done signal not asserted")
            
            passed += 1
            cocotb.log.info(f"  PASS: n={n_val} -> {result}")
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\nSummary: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")