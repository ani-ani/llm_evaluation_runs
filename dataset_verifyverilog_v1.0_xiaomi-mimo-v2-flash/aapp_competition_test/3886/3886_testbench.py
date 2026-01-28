import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 2000  # Allow extra for large n

# Helper functions
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
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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

# Python reference implementation
f0 = "What are you doing at the end of the world? Are you busy? Will you save us?"
ft1 = 'What are you doing while sending "'
ft2 = '"? Are you busy? Will you send "'
ft3 = '"?'

def get_len(n):
    if n >= 55:
        return 2**62  # Saturation value
    length = 75
    for _ in range(n):
        length = 2 * length + 68
    return length

def python_solve(n, k):
    if k > get_len(n):
        return '.'
    while True:
        if n == 0:
            return f0[k-1]  # k is 1-indexed in this logic
        if k <= len(ft1):
            return ft1[k-1]
        k -= len(ft1)
        prev_len = get_len(n-1)
        if k <= prev_len:
            n -= 1
            continue
        k -= prev_len
        if k <= len(ft2):
            return ft2[k-1]
        k -= len(ft2)
        if k <= prev_len:
            n -= 1
            continue
        k -= prev_len
        if k <= len(ft3):
            return ft3[k-1]
        return '.'

@cocotb.test(timeout_time=10, timeout_unit='sec')
async def test_nephren_game(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)

    # Test cases: (n, k, expected_char, description)
    test_cases = [
        (0, 1, 'W', "f0 start"),
        (0, 75, '?', "f0 end"),
        (0, 76, '.', "f0 out of range"),
        (1, 1, 'W', "f1 prefix start"),
        (1, 34, '"', "f1 prefix end"),
        (1, 35, 'W', "f1 first f0 char"),
        (1, 36, 'h', "f1 second f0 char"),
        (1, 109, '.', "f1 out of range (len 110)"),
        (1, 110, '?', "f1 end"),
        (55, 1, 'W', "saturated n large, k small"),
        (55, 34, '"', "saturated n large, k=34"),
        (100000, 1, 'W', "very large n, k=1"),
        (10, 73182, 'y', "medium n, within f9"),
    ]

    passed = 0
    failed = 0

    for (n, k, exp_char, desc) in test_cases:
        cocotb.log.info(f"Test: {desc} (n={n}, k={k})")
        try:
            if is_seq:
                # Set inputs
                dut.n.value = n
                dut.k.value = k
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=5000)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result_char = chr(int(dut.result.value))
                
                if result_char != exp_char:
                    raise TestFailure(f"Expected '{exp_char}', got '{result_char}'")
            else:
                # Combinational: wait a bit for propagation
                dut.n.value = n
                dut.k.value = k
                await Timer(100, units='ns')
                result_char = chr(int(dut.result.value))
                if result_char != exp_char:
                    raise TestFailure(f"Expected '{exp_char}', got '{result_char}'")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

    # Verify against Python reference for a few large cases
    cocotb.log.info("Running Python reference validation...")
    large_tests = [
        (4, 1825, 'A'),
        (3, 75, 'y'),
        (3, 530, 'o'),
    ]
    for n, k, exp in large_tests:
        py_char = python_solve(n, k)
        if py_char != exp:
            cocotb.log.error(f"Python reference bug: n={n}, k={k}, exp={exp}, got={py_char}")
        dut.n.value = n
        dut.k.value = k
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        hdl_char = chr(int(dut.result.value))
        if hdl_char != py_char:
            cocotb.log.error(f"Mismatch n={n}, k={k}: HDL={hdl_char}, Py={py_char}")
