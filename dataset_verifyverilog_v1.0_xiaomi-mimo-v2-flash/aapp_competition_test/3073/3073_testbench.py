import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
MAX_CARDS = 16
CLK_NS = 10
MAX_CYCLES = 200

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, width):
    # Handle signed clamping for simplicity
    max_val = (1 << (width - 1)) - 1
    min_val = -(1 << (width - 1))
    if v > max_val: return max_val
    if v < min_val: return min_val
    return v

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'calc'): dut.calc.value = 0
    if has_signal(dut, 'card_valid'): dut.card_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def write_card(dut, idx, r, c, a, b, p):
    # Clamp values to 16-bit signed/unsigned as appropriate
    # R, C, A, B are signed 16-bit
    dut.card_r.value = clamp_to_width(r, 16)
    dut.card_c.value = clamp_to_width(c, 16)
    dut.card_a.value = clamp_to_width(a, 16)
    dut.card_b.value = clamp_to_width(b, 16)
    # P is price, typically unsigned, but we store in 16-bit
    dut.card_p.value = clamp_to_width(p, 16)
    dut.card_idx.value = idx
    dut.card_valid.value = 1

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_knight_treasure(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Missing 'clk' signal")

    test_cases = [
        {
            "cards": [
                (3, 3, 2, 2, 100), # Card 0: Start
                (1, 1, 1, 1, 500), # Card 1
            ],
            "expected_cost": 600,
            "expected_possible": 1
        },
        {
            "cards": [
                (2, 0, 2, 1, 100), # Card 0: Start
                (6, 0, 8, 1, 1),   # Card 1
            ],
            "expected_cost": 100,
            "expected_possible": 1
        },
        {
            "cards": [
                (1, 0, 100, 50, 100),
                (1, 50, 50, 25, 100),
                (26, 0, 20, 30, 123),
            ],
            "expected_cost": -1,
            "expected_possible": 0
        }
    ]

    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {tc_idx + 1}")
        
        # Load cards
        for i, (r, c, a, b, p) in enumerate(tc["cards"]):
            write_card(dut, i, r, c, a, b, p)
            await RisingEdge(dut.clk)
        
        dut.card_valid.value = 0
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read results
        if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
            raise TestFailure(f"Test {tc_idx+1}: Done signal not high")
            
        result_cost = int(dut.min_cost.value)
        result_possible = int(dut.possible.value)
        
        cocotb.log.info(f"Result: Cost={result_cost}, Possible={result_possible}")
        
        # Check result
        # Note: The HDL might output 0 if impossible, or handle -1 as special code (e.g. 65535)
        # Since we use 16-bit unsigned, -1 is 65535. 
        # Let's assume the design outputs 0 cost if impossible, or a flag.
        # The prompt asks for "min_cost[15:0]" and "possible" bit.
        
        if tc["expected_possible"] == 1:
            if result_possible != 1:
                 raise TestFailure(f"Test {tc_idx+1}: Expected possible=1, got {result_possible}")
            if result_cost != tc["expected_cost"]:
                raise TestFailure(f"Test {tc_idx+1}: Expected cost {tc['expected_cost']}, got {result_cost}")
        else:
            if result_possible != 0:
                raise TestFailure(f"Test {tc_idx+1}: Expected possible=0, got {result_possible}")
            # Cost is irrelevant if impossible, usually 0 or max

        await reset_dut(dut)

    cocotb.log.info("All tests passed")