import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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
        v = (1 << bits) + v
    return min((1 << bits) - 1, max(0, v))

def wait_signal(dut, signal_name, timeout_cycles=1000):
    # Helper for waiting on a signal using a generator
    async def waiter():
        for _ in range(timeout_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(getattr(dut, signal_name).value) and int(getattr(dut, signal_name).value) == 1:
                return True
        raise TestFailure(f"Signal {signal_name} timeout")
    return waiter()

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(cycles): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

async def write_string(dut, s_str, max_len=64):
    # s_str is the string of digits from input
    digits = [int(c) for c in s_str]
    if len(digits) > max_len:
        digits = digits[:max_len]
    
    # Write length
    if has_signal(dut, 'len'):
        dut.len.value = len(digits)
    
    # Write digits to array s[0:63]
    for i, d in enumerate(digits):
        if has_signal(dut, f's_{i}'):
            getattr(dut, f's_{i}').value = clamp_to_width(d, 4)
        elif hasattr(dut.s, '__iter__'):
            # If s is an array of signals (e.g. dut.s[0], dut.s[1]...)
            try:
                dut.s[i].value = clamp_to_width(d, 4)
            except Exception:
                pass

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rectangle_sum(dut):
    # Setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (target_a, s_string, expected_count)
    # We scale down inputs to fit HDL constraints (len <= 64)
    test_cases = [
        (10, "12345", 6),
        (16, "439873893693495623498263984765", 40),
        (0, "1230", 19),
        (0, "0011", 51),
        (1, "11111", 25),
        (4, "111", 4),
        (0, "0000", 100) # 4*4=16 subarrays, logic specific to a=0
    ]

    passed = 0
    failed = 0

    for i, (a_val, s_str, exp_val) in enumerate(test_cases):
        # Skip if string too long for our simplified HDL
        if len(s_str) > 64:
            cocotb.log.info(f"Skipping test {i+1}: String length {len(s_str)} > 64")
            continue

        cocotb.log.info(f"Test {i+1}: a={a_val}, s='{s_str}', expected={exp_val}")
        try:
            # Write inputs
            if has_signal(dut, 'target_a'):
                dut.target_a.value = clamp_to_width(a_val, 32)
            elif has_signal(dut, 'a'):
                dut.a.value = clamp_to_width(a_val, 32)
            
            await write_string(dut, s_str)

            if has_signal(dut, 'clk'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_signal(dut, 'done')
            else:
                await Timer(100, units='ns')

            # Read result
            res_signal = None
            if has_signal(dut, 'result'): res_signal = dut.result
            elif has_signal(dut, 'out'): res_signal = dut.out
            
            if res_signal is None:
                raise TestFailure("No result signal found")

            result = int(res_signal.value)
            if result != exp_val:
                raise TestFailure(f"Expected {exp_val}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
