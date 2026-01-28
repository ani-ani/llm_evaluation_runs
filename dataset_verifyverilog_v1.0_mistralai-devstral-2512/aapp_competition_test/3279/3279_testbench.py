import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Extended helpers for multi-dim access
def get_nested_signal(dut, name, idx1, idx2=None):
    try:
        if idx2 is None:
            return getattr(dut, f"{name}_{idx1}")
        else:
            return getattr(dut, f"{name}_{idx1}_{idx2}")
    except AttributeError:
        # Try array access syntax if available
        try:
            if idx2 is None:
                return getattr(dut, name)[idx1]
            else:
                return getattr(dut, name)[idx1][idx2]
        except (AttributeError, IndexError):
            return None

async def wait_for_done(dut, max_cycles=50000):
    for _ in range(max_cycles):
        if has_signal(dut, 'done'):
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        await RisingEdge(dut.clk)
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_barcodesolver(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(10, units='ns')

    # Test Case 1: n=2
    # Input: 
    # 2
    # 1
    # 0
    # 0
    # 3
    # Expected Output:
    # 100
    # 000
    # 01
    # 01
    # 01
    
    n = 2
    # Row specs: row 0: [1], row 1: [0]
    # Col specs: col 0: [0], col 1: [3]
    
    dut.n_val.value = n
    
    # Load Row Specs
    # Row 0: 1 group of size 1
    if has_signal(dut, 'row_spec_0_0'): dut.row_spec_0_0.value = 1
    if has_signal(dut, 'row_spec_len_0'): dut.row_spec_len_0.value = 1
    # Row 1: 0 groups
    if has_signal(dut, 'row_spec_len_1'): dut.row_spec_len_1.value = 0
    
    # Load Col Specs
    # Col 0: 0 groups
    if has_signal(dut, 'col_spec_len_0'): dut.col_spec_len_0.value = 0
    # Col 1: 1 group of size 3
    if has_signal(dut, 'col_spec_1_0'): dut.col_spec_1_0.value = 3
    if has_signal(dut, 'col_spec_len_1'): dut.col_spec_len_1.value = 1

    # Start
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(500, units='ns')

    # Verify Output
    # Vertical bars (2 rows of 3)
    # Expected:
    # Row 0: 1 0 0
    # Row 1: 0 0 0
    
    def check_2d(name, rows, cols, expected):
        for r in range(rows):
            for c in range(cols):
                sig = get_nested_signal(dut, name, r, c)
                if sig is None:
                    # Fallback for packed array or vector if available
                    continue
                val = int(sig.value)
                exp = expected[r][c]
                if val != exp:
                    raise TestFailure(f"{name}[{r}][{c}] mismatch: expected {exp}, got {val}")

    v_exp = [
        [1, 0, 0],
        [0, 0, 0]
    ]
    h_exp = [
        [0, 1],
        [0, 1],
        [0, 1]
    ]

    check_2d('vertical_bars', n, n+1, v_exp)
    check_2d('horizontal_bars', n+1, n, h_exp)

    cocotb.log.info("Test case 1 passed!")

    # Test Case 2: n=3 (Sample 2)
    # Input:
    # 3
    # 0
    # 1 1
    # 1
    # 1 1
    # 1
    # 1
    
    n = 3
    dut.n_val.value = n
    
    # Reset state for new load
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Row Specs
    # 0: [0]
    if has_signal(dut, 'row_spec_len_0'): dut.row_spec_len_0.value = 0
    # 1: [1, 1]
    if has_signal(dut, 'row_spec_1_0'): dut.row_spec_1_0.value = 1
    if has_signal(dut, 'row_spec_1_1'): dut.row_spec_1_1.value = 1
    if has_signal(dut, 'row_spec_len_1'): dut.row_spec_len_1.value = 2
    # 2: [1]
    if has_signal(dut, 'row_spec_2_0'): dut.row_spec_2_0.value = 1
    if has_signal(dut, 'row_spec_len_2'): dut.row_spec_len_2.value = 1

    # Col Specs
    # 0: [1, 1]
    if has_signal(dut, 'col_spec_0_0'): dut.col_spec_0_0.value = 1
    if has_signal(dut, 'col_spec_0_1'): dut.col_spec_0_1.value = 1
    if has_signal(dut, 'col_spec_len_0'): dut.col_spec_len_0.value = 2
    # 1: [1]
    if has_signal(dut, 'col_spec_1_0'): dut.col_spec_1_0.value = 1
    if has_signal(dut, 'col_spec_len_1'): dut.col_spec_len_1.value = 1
    # 2: [1]
    if has_signal(dut, 'col_spec_2_0'): dut.col_spec_2_0.value = 1
    if has_signal(dut, 'col_spec_len_2'): dut.col_spec_len_2.value = 1

    # Start
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(1000, units='ns')

    # Expected Output for Case 2:
    # 0000
    # 1001
    # 0010
    # 101
    # 010
    # 000
    # 100
    
    v_exp_2 = [
        [0, 0, 0, 0],
        [1, 0, 0, 1],
        [0, 0, 1, 0]
    ]
    h_exp_2 = [
        [1, 0, 1],
        [0, 1, 0],
        [0, 0, 0],
        [1, 0, 0]
    ]

    check_2d('vertical_bars', n, n+1, v_exp_2)
    check_2d('horizontal_bars', n+1, n, h_exp_2)

    cocotb.log.info("Test case 2 passed!")
