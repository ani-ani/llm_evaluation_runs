import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for the problem
DATA_WIDTH = 16
NUM_CARDS = 2
CARDS_PER_TEST = 2  # We test pairs of cards at a time
CLK_NS = 10
MAX_CYCLES = 500

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

# Test inputs from the problem
INPUT_CARD_1 = [
    [3, 29, 45, 56, 68],
    [1, 19, 43, 50, 72],
    [11, 25, 40, 49, 61],
    [9, 23, 31, 58, 63],
    [4, 27, 42, 54, 71]
]

INPUT_CARD_2 = [
    [14, 23, 39, 59, 63],
    [8, 17, 35, 55, 61],
    [15, 26, 42, 53, 71],
    [10, 25, 31, 57, 64],
    [6, 20, 44, 52, 68]
]

def flatten_card(card):
    flat = []
    for row in card:
        flat.extend(row)
    return flat

def assign_card(dut, card_flat, card_index, width=DATA_WIDTH):
    """Assign a flattened card to the dut's input array."""
    # Create array name based on card index
    # Assuming dut has signals like arr_0_0, arr_0_1, ... arr_0_24 for card 0
    # and arr_1_0, arr_1_1, ... arr_1_24 for card 1
    for i, val in enumerate(card_flat):
        signal_name = f'arr_{card_index}_{i}'
        if hasattr(dut, signal_name):
            getattr(dut, signal_name).value = clamp_to_width(val, width)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_bingo_tie(dut):
    # Start the clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Prepare input data
    card1_flat = flatten_card(INPUT_CARD_1)
    card2_flat = flatten_card(INPUT_CARD_2)
    
    # Assign cards to the DUT
    # We assume the DUT has inputs for 2 cards (for the pairwise test)
    assign_card(dut, card1_flat, 0)
    assign_card(dut, card2_flat, 1)
    
    # Start the analysis
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read results
    if not is_value_defined(dut.done.value):
        raise TestFailure("Done signal is undefined")
    
    if int(dut.done.value) != 1:
        raise TestFailure("Done signal did not go high")
    
    # Check a and b outputs
    # Expected: a=1, b=2 (1-based indices)
    a = safe_int(dut.a.value)
    b = safe_int(dut.b.value)
    
    cocotb.log.info(f"Result: a={a}, b={b}")
    
    if a != 1 or b != 2:
        raise TestFailure(f"Expected tie between cards 1 and 2, got cards {a} and {b}")

# Additional test case for no ties
@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_no_tie(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Two cards with no shared numbers that complete a row simultaneously
    # Simplified: Card 1 has 1,2,3,4,5 in row 0. Card 2 has 6,7,8,9,10 in row 0.
    card1_no_tie = [
        [1, 2, 3, 4, 5],
        [11, 12, 13, 14, 15],
        [21, 22, 23, 24, 25],
        [31, 32, 33, 34, 35],
        [41, 42, 43, 44, 45]
    ]
    card2_no_tie = [
        [6, 7, 8, 9, 10],
        [16, 17, 18, 19, 20],
        [26, 27, 28, 29, 30],
        [36, 37, 38, 39, 40],
        [46, 47, 48, 49, 50]
    ]
    
    assign_card(dut, flatten_card(card1_no_tie), 0)
    assign_card(dut, flatten_card(card2_no_tie), 1)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    a = safe_int(dut.a.value)
    b = safe_int(dut.b.value)
    
    cocotb.log.info(f"No tie result: a={a}, b={b}")
    
    if a != 0 or b != 0:
        raise TestFailure(f"Expected no tie (0,0), got cards {a} and {b}")