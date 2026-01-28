import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, RESULT_WIDTH, CLK_NS, MAX_CYCLES = 8, 16, 10, 256
N_MAX = 8
Q_MAX = 8

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
    if v < 0:
        return (1 << bits) + v if v >= -(1 << bits) else 0
    return min((1 << bits) - 1, max(0, v))

def fun_value(a, b, k):
    if k < 1: return 0
    val = a - ((k-1)**2) * b
    return val if val > 0 else 0

def compute_max_fun(coasters, T):
    max_rides = 8
    dp = [0] * (T + 1)
    for time in range(1, T + 1):
        for idx, (a, b, t) in enumerate(coasters):
            if t == 0: continue
            for rides in range(1, max_rides + 1):
                ride_time = rides * t
                if ride_time > time: break
                fun_per_ride = fun_value(a, b, rides)
                if fun_per_ride <= 0: break
                total_fun = dp[time - ride_time] + rides * fun_per_ride
                if total_fun > dp[time]:
                    dp[time] = total_fun
    return dp[T]

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

async def setup_query(dut, coasters, query_time):
    dut.N.value = len(coasters)
    dut.Query_T.value = query_time
    for i in range(N_MAX):
        if i < len(coasters):
            a, b, t = coasters[i]
            getattr(dut, f'a_{i}').value = clamp_to_width(a, 16)
            getattr(dut, f'b_{i}').value = clamp_to_width(b, 16)
            getattr(dut, f't_{i}').value = clamp_to_width(t, 8)
        else:
            getattr(dut, f'a_{i}').value = 0
            getattr(dut, f'b_{i}').value = 0
            getattr(dut, f't_{i}').value = 0

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_fun_maximizer(dut):
    if not has_signal(dut, 'clk'):
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([(5, 0, 5), (7, 0, 7)], 88),
        ([(5, 0, 5), (7, 0, 7)], 5),
        ([(5, 0, 5), (7, 0, 7)], 6),
        ([(5, 0, 5), (7, 0, 7)], 7),
        ([(100, 3, 2)], 2),
        ([(100, 3, 2)], 3),
        ([(100, 3, 2)], 4),
        ([(100, 3, 2)], 5),
        ([(100, 3, 2)], 100),
    ]
    
    passed = failed = 0
    
    for i, (coasters, query_time) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {len(coasters)} coasters, T={query_time}")
        
        expected = compute_max_fun(coasters, query_time)
        cocotb.log.info(f"  Expected: {expected}")
        
        await setup_query(dut, coasters, query_time)
        await Timer(50, units='ns')
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        try:
            if has_signal(dut, 'busy'):
                await wait_for_done(dut)
            else:
                await Timer(5000, units='ns')
            
            result = int(dut.result.value)
            result = to_signed(result, 16)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
