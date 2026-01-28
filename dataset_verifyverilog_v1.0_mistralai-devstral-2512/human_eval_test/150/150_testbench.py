import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 300

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    v = int(v)
    # Handle negative numbers by masking (unsigned representation)
    if v < 0:
        v = (1 << bits) + v
    return v & ((1 << bits) - 1)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done_o.value) and int(dut.done_o.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_prime_checker(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational fallback (not expected for this FSM)
        await Timer(100, units='ns')

    test_cases = [
        (7, 34, 12, 34, "7 is prime"),
        (15, 8, 5, 5, "15 is not prime"),
        (3, 33, 5212, 33, "3 is prime"),
        (1259, 3, 52, 3, "1259 is prime"),
        (7919, -1, 12, -1, "7919 is prime (negative x)"),
        (3609, 1245, 583, 583, "3609 is not prime"),
        (91, 56, 129, 129, "91 is not prime"),
        (6, 34, 1234, 1234, "6 is not prime"),
        (1, 2, 0, 0, "1 is not prime"),
        (2, 2, 0, 2, "2 is prime")
    ]

    passed = 0
    failed = 0

    for i, (n_val, x_val, y_val, exp_val, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n_val}, x={x_val}, y={y_val})")
        try:
            dut.n_i.value = clamp_to_width(n_val, DATA_WIDTH)
            dut.x_i.value = clamp_to_width(x_val, DATA_WIDTH)
            dut.y_i.value = clamp_to_width(y_val, DATA_WIDTH)

            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')

            if not is_value_defined(dut.result_o.value):
                raise TestFailure("Result undefined")
            
            result_raw = int(dut.result_o.value)
            # Convert back from unsigned 16-bit if needed (Python int is signed)
            # But the HDL output is unsigned 16-bit. We compare logic values.
            # Logic value = expected value masked to 16 bits.
            exp_logic = clamp_to_width(exp_val, DATA_WIDTH)
            
            if result_raw != exp_logic:
                raise TestFailure(f"Expected logic {exp_logic} ({exp_val}), got {result_raw}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")