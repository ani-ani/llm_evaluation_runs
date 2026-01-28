import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

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

DATA_WIDTH = 4
MAX_DIGITS = 8
MAX_SWAPS = 16
CLK_NS = 10
MAX_CYCLES = 300

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def get_digits_from_number(n_str):
    return [int(d) for d in n_str.strip()]

async def write_digits(dut, digits, num_digits):
    for i in range(MAX_DIGITS):
        if i < num_digits:
            dut.digits_in[i].value = clamp_to_width(digits[i], DATA_WIDTH)
        else:
            dut.digits_in[i].value = 0
    dut.num_digits.value = clamp_to_width(num_digits, 3)

def read_digits(dut, num_digits):
    result = []
    for i in range(MAX_DIGITS):
        if i < num_digits:
            result.append(int(dut.digits_out[i].value))
    return result

def compute_max_by_swaps(digits, k, num_digits):
    if num_digits <= 1:
        return digits
    
    current_states = {}
    initial_state = tuple(digits)
    current_states[initial_state] = 0
    
    for swap_count in range(k + 1):
        next_states = {}
        
        for state in current_states.keys():
            state_list = list(state)
            if swap_count == k:
                if state not in next_states:
                    next_states[state] = swap_count
            else:
                for i in range(num_digits):
                    for j in range(i + 1, num_digits):
                        if i == 0 and state_list[j] == 0:
                            continue
                        if j == 0 and state_list[i] == 0:
                            continue
                        new_state = state_list.copy()
                        new_state[i], new_state[j] = new_state[j], new_state[i]
                        new_state_tuple = tuple(new_state)
                        if new_state_tuple not in next_states:
                            next_states[new_state_tuple] = swap_count + 1
        
        current_states = next_states
    
    max_val = -1
    best_state = digits
    for state in current_states.keys():
        val = 0
        for d in state:
            val = val * 10 + d
        if val > max_val:
            max_val = val
            best_state = list(state)
    
    return best_state

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_swap_digits(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ("1374", 2, 4, "7413"),
        ("210", 1, 3, "201"),
        ("666", 3, 3, "666"),
        ("12345", 3, 5, "54321"),
        ("1023", 1, 4, "2013"),
        ("4321", 2, 4, "4321"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_str, k_val, num_digits, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {n_str} with k={k_val}")
        try:
            digits = get_digits_from_number(n_str)
            expected = get_digits_from_number(expected_str)
            
            await write_digits(dut, digits, num_digits)
            dut.k.value = clamp_to_width(k_val, 5)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                raise TestFailure("Valid signal not set")
            
            result = read_digits(dut, num_digits)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")