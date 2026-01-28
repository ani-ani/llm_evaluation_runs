import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 4  # One-hot 0-9
MAX_N = 32
CLK_NS = 10
MAX_CYCLES = 2000

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

def digits_to_onehot(digit_list):
    """Converts list of integers (0-9) to list of one-hot 4-bit values."""
    return [1 << d for d in digit_list]

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_beautiful_integer(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational, just wait for stability
        await Timer(100, units='ns')

    # Helper to write inputs
    async def set_inputs(n_val, k_val, x_str):
        if is_seq:
            dut.start.value = 1
            dut.n.value = n_val
            dut.k.value = k_val
            
            x_digits = [int(c) for c in x_str]
            onehot_x = digits_to_onehot(x_digits)
            
            # Write x_digits array
            for i in range(n_val):
                dut.x_digits[i].value = clamp_to_width(onehot_x[i], DATA_WIDTH)
            
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            # Combinational
            dut.n.value = n_val
            dut.k.value = k_val
            x_digits = [int(c) for c in x_str]
            onehot_x = digits_to_onehot(x_digits)
            for i in range(n_val):
                dut.x_digits[i].value = clamp_to_width(onehot_x[i], DATA_WIDTH)
            await Timer(100, units='ns')

    # Helper to check results
    def check_output(expected_str):
        m_val = int(dut.m.value)
        if m_val != len(expected_str):
            raise TestFailure(f"Expected m={len(expected_str)}, got {m_val}")
        
        for i in range(m_val):
            # Extract digit from one-hot
            val = int(dut.y_digits[i].value)
            # Convert one-hot to digit
            digit = 0
            for b in range(10):
                if val == (1 << b):
                    digit = b
                    break
            else:
                # Handle x or z or multiple bits set
                if val == 0:
                    digit = 0
                else:
                    # Find lowest set bit (simplest approximation for one-hot error)
                    for b in range(10):
                        if val & (1 << b):
                            digit = b
                            break
            
            if digit != int(expected_str[i]):
                raise TestFailure(f"Mismatch at index {i}: expected {expected_str[i]}, got {digit}")

    # Test cases
    test_cases = [
        (3, 2, "353", "353"),
        (4, 2, "1234", "1313"),
        (5, 4, "99999", "99999"),
        (5, 4, "41242", "41244"),
        (5, 2, "16161", "16161"),
        (2, 1, "33", "33"),
        (2, 1, "99", "99"),
        (2, 1, "31", "33"),
        (5, 1, "99999", "99999"),
        (5, 1, "26550", "33333"),
        (5, 1, "22222", "22222"),
        (5, 2, "99999", "99999"),
        (5, 2, "16137", "16161"),
        (3, 2, "192", "202"),
        (4, 2, "1920", "2020"),
        (6, 3, "129130", "130130"),
        (5, 3, "18920", "19019"),
    ]

    passed = 0
    failed = 0

    for n, k, x, exp in test_cases:
        try:
            cocotb.log.info(f"Running test: n={n}, k={k}, x={x}")
            await set_inputs(n, k, x)
            check_output(exp)
            passed += 1
            cocotb.log.info(f"PASS: {x} -> {exp}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {x} -> Expected {exp}. Reason: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")