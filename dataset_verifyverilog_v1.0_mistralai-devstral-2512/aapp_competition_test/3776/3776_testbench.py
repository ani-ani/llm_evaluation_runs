import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_broken_clock(dut):
    # Setup
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (format, (h1,h0,m1,m0), expected (h1,h0,m1,m0))
    # format: 0 = 24h, 1 = 12h
    test_cases = [
        (0, (1,7,3,0), (1,7,3,0), "24h 17:30 correct"),
        (1, (1,7,3,0), (0,7,3,0), "12h 17:30 -> 07:30"),
        (0, (9,9,9,9), (0,9,0,9), "24h 99:99 -> 09:09"),
        (1, (0,5,5,4), (0,5,5,4), "12h 05:54 correct"),
        (1, (0,0,0,5), (0,1,0,5), "12h 00:05 -> 01:05"),
        (0, (2,3,8,0), (2,3,0,0), "24h 23:80 -> 23:00"),
        (0, (7,3,1,6), (0,3,1,6), "24h 73:16 -> 03:16"),
        (1, (0,3,7,7), (0,3,0,7), "12h 03:77 -> 03:07"),
        (1, (4,7,8,3), (0,7,0,3), "12h 47:83 -> 07:03"),
        (0, (2,3,8,8), (2,3,0,8), "24h 23:88 -> 23:08"),
        (0, (5,1,6,7), (0,1,0,7), "24h 51:67 -> 01:07"),
        (1, (1,0,3,3), (1,0,3,3), "12h 10:33 correct"),
        (1, (0,0,0,1), (0,1,0,1), "12h 00:01 -> 01:01"),
        (1, (0,7,7,4), (0,7,0,4), "12h 07:74 -> 07:04"),
        (1, (0,0,6,0), (0,1,1,0), "12h 00:60 -> 01:00"),
        (0, (0,8,3,2), (0,8,3,2), "24h 08:32 correct"),
        (0, (4,2,5,9), (0,2,5,9), "24h 42:59 -> 02:59"),
        (0, (1,9,8,7), (1,9,0,7), "24h 19:87 -> 19:07"),
        (0, (2,6,9,8), (0,6,0,8), "24h 26:98 -> 06:08"),
        (1, (1,2,9,1), (1,2,0,1), "12h 12:91 -> 12:01"),
        (1, (1,1,3,0), (1,1,3,0), "12h 11:30 correct"),
        (1, (9,0,3,2), (1,0,3,2), "12h 90:32 -> 10:32"),
        (1, (0,3,6,9), (0,3,0,9), "12h 03:69 -> 03:09"),
        (1, (3,3,8,3), (0,3,0,3), "12h 33:83 -> 03:03"),
        (0, (1,0,4,5), (1,0,4,5), "24h 10:45 correct"),
        (0, (6,5,1,2), (0,5,1,2), "24h 65:12 -> 05:12"),
        (0, (2,2,6,4), (2,2,2,4), "24h 22:64 -> 22:04"),
        (0, (4,8,9,1), (0,8,0,1), "24h 48:91 -> 08:01"),
        (1, (0,2,5,1), (0,2,5,1), "12h 02:51 correct"),
        (1, (4,0,1,1), (1,0,1,1), "12h 40:11 -> 10:11"),
        (1, (0,2,8,6), (0,2,0,6), "12h 02:86 -> 02:06"),
        (1, (9,9,9,6), (0,9,0,6), "12h 99:96 -> 09:06"),
        (0, (1,9,2,4), (1,9,2,4), "24h 19:24 correct"),
        (0, (5,5,4,9), (0,5,4,9), "24h 55:49 -> 05:49"),
        (0, (0,1,9,7), (0,1,0,7), "24h 01:97 -> 01:07"),
        (0, (3,9,6,8), (0,9,0,8), "24h 39:68 -> 09:08"),
        (0, (2,4,0,0), (0,4,0,0), "24h 24:00 -> 04:00"),
        (1, (9,1,0,0), (0,1,0,0), "12h 91:00 -> 01:00"),
        (0, (0,0,3,0), (0,0,3,0), "24h 00:30 correct"),
        (1, (1,3,2,0), (0,3,2,0), "12h 13:20 -> 03:20"),
        (1, (1,3,0,0), (0,3,0,0), "12h 13:00 -> 03:00"),
        (1, (4,2,3,5), (0,2,3,5), "12h 42:35 -> 02:35"),
        (1, (2,0,0,0), (1,0,0,0), "12h 20:00 -> 10:00"),
        (1, (2,1,0,0), (0,1,0,0), "12h 21:00 -> 01:00"),
        (0, (1,0,1,0), (1,0,1,0), "24h 10:10 correct"),
        (0, (3,0,4,0), (0,0,4,0), "24h 30:40 -> 00:40"),
        (0, (1,2,0,0), (1,2,0,0), "24h 12:00 correct"),
        (1, (1,0,6,0), (1,0,0,0), "12h 10:60 -> 10:00"),
        (0, (3,0,0,0), (0,0,0,0), "24h 30:00 -> 00:00"),
        (0, (3,4,0,0), (0,4,0,0), "24h 34:00 -> 04:00"),
        (1, (2,2,0,0), (0,2,0,0), "12h 22:00 -> 02:00"),
        (1, (2,0,2,0), (1,0,2,0), "12h 20:20 -> 10:20"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (fmt, broken, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Inputs
            dut.format.value = fmt
            dut.broken_h1.value = broken[0]
            dut.broken_h0.value = broken[1]
            dut.broken_m1.value = broken[2]
            dut.broken_m0.value = broken[3]
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            if not has_signal(dut, 'done'):
                await Timer(5000, units='ns')
            else:
                await wait_for_done(dut)
            
            # Check outputs
            o_h1 = int(dut.correct_h1.value)
            o_h0 = int(dut.correct_h0.value)
            o_m1 = int(dut.correct_m1.value)
            o_m0 = int(dut.correct_m0.value)
            
            res = (o_h1, o_h0, o_m1, o_m0)
            exp = expected
            
            if res != exp:
                raise TestFailure(f"Expected {exp}, got {res}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed")
