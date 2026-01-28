import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, timeout=100):
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure("Timeout waiting for done")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_duel_game(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test cases derived from problem examples and logic
    # Tuple: (n, k, state_string, expected_result_code)
    # Expected codes: 0=tokitsukaze, 1=quailty, 2=once_again
    test_cases = [
        (4, 2, "0101", 1),  # quailty
        (6, 1, "010101", 2),  # once again
        (6, 5, "010101", 0),  # tokitsukaze
        (4, 1, "0011", 2),  # once again
        (1, 1, "1", 0),  # tokitsukaze
        (1, 1, "0", 0),  # tokitsukaze
        (2, 1, "11", 0),  # tokitsukaze
        (2, 1, "00", 0),  # tokitsukaze
        (2, 2, "01", 0),  # tokitsukaze
        (2, 1, "10", 0),  # tokitsukaze
        (4, 1, "1100", 2),  # once again
        (6, 2, "000111", 2)  # once again
    ]

    passed = 0
    failed = 0

    for n, k, state_str, expected in test_cases:
        # Construct state integer
        state_val = 0
        for i, char in enumerate(state_str):
            if char == '1':
                state_val |= (1 << i)
        
        dut.n.value = n
        dut.k.value = k
        dut.state.value = state_val
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test failed for n={n}, k={k}, state={state_str}: Result undefined")
            failed += 1
            continue
            
        res = int(dut.result.value)
        if res != expected:
            cocotb.log.error(f"Test failed for n={n}, k={k}, state={state_str}: Expected {expected}, got {res}")
            failed += 1
        else:
            passed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
