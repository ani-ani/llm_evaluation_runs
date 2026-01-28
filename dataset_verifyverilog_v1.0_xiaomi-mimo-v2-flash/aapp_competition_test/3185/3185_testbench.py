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

DATA_WIDTH = 64
N_WIDTH = 8
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_inverse_factorial(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Factorials for n=0..27 (0! =1, 1! =1, 2!=2, 3!=6, 4!=24, 5!=120, 6!=720, 7!=5040, 8!=40320, 9!=362880, 10!=3628800, 11!=39916800, 12!=479001600, 13!=6227020800, 14!=87178291200, 15!=1307674368000, 16!=20922789888000, 17!=355687428096000, 18!=6402373705728000, 19!=121645100408832000, 20!=2432902008176640000, 21!=51090942171709440000, 22!=1124000727777607680000, 23!=25852016738884976640000, 24!=620448401733239439360000, 25!=15511210043330985984000000, 26!=403291461126605635584000000, 27!=10888869450418352160768000000)
    test_cases = [
        (120, 5, "5!"),
        (51090942171709440000, 21, "21!"),
        (10888869450418352160768000000, 27, "27!"),
        (1, 0, "0! and 1! both 1"),
        (2, 2, "2!"),
        (6, 3, "3!"),
        (24, 4, "4!"),
    ]
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            if is_seq:
                dut.x.value = inp
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                dut.x.value = inp
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.n.value):
                raise TestFailure("Result n undefined")
            result = int(dut.n.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed: raise TestFailure(f"{failed} tests failed")