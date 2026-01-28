import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 4  # Card values 0-16
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 500

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: return 0
    if v > max_val: return max_val
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        if i >= ARRAY_SIZE:
            break
        target = getattr(dut, name)[i]
        target.value = clamp_to_width(v, width)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_card_operations(dut):
    # Setup clock if synchronous
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic fallback (unlikely for this problem)
        await Timer(100, units='ns')

    test_cases = [
        # (n, a, b, expected_result)
        (3, [0, 2, 0], [3, 0, 1], 2),
        (3, [0, 2, 0], [1, 0, 3], 4),
        (1, [1], [0], 1),
        (1, [0], [1], 0),
        (2, [0, 0], [1, 2], 0),
        (2, [0, 0], [2, 1], 4),
        (3, [0, 0, 0], [1, 3, 2], 4),
        (8, [0]*8, [7, 8, 1, 2, 3, 4, 5, 6], 11),
        (3, [0, 0, 1], [2, 0, 3], 4),
    ]

    passed = 0
    failed = 0

    for idx, (n, hand_vals, pile_vals, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {idx+1}: n={n}, Hand={hand_vals}, Pile={pile_vals}, Expected={expected}")
        
        try:
            # Pad inputs to 16 elements with zeros
            a_padded = hand_vals + [0] * (16 - len(hand_vals))
            b_padded = pile_vals + [0] * (16 - len(pile_vals))

            if is_seq:
                # Write inputs
                dut.n.value = n
                await write_array(dut, 'a', a_padded, DATA_WIDTH)
                await write_array(dut, 'b', b_padded, DATA_WIDTH)

                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0

                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                passed += 1
            else:
                # Combinational check (just wait for inputs to settle)
                dut.n.value = n
                await write_array(dut, 'a', a_padded, DATA_WIDTH)
                await write_array(dut, 'b', b_padded, DATA_WIDTH)
                await Timer(50, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined")
                    
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                passed += 1

        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} FAILED: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
