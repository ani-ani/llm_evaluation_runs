import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 2
GRID_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_maze_solver(dut):
    """Test maze solver with adapted 8x8 grid"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, m, k, input_grid, expected_output_grid)
    test_cases = [
        (
            3, 4, 2,
            [
                [0, 1, 1, 0],
                [1, 1, 0, 1],
                [0, 1, 1, 1]
            ],
            [
                [0, 1, 2, 0],
                [2, 1, 0, 1],
                [0, 1, 1, 1]
            ]
        ),
        (
            3, 3, 1,
            [
                [1, 1, 1],
                [1, 0, 1],
                [1, 1, 1]
            ],
            [
                [2, 1, 1],
                [1, 0, 1],
                [1, 1, 1]
            ]
        ),
        (
            1, 1, 0,
            [[1]],
            [[1]]
        ),
        (
            2, 3, 1,
            [
                [1, 1, 0],
                [0, 1, 1]
            ],
            [
                [2, 1, 0],
                [0, 1, 1]
            ]
        )
    ]
    
    for i, (n, m, k, grid_in, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: n={n}, m={m}, k={k}")
        
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        dut.k.value = k
        
        # Write grid_in (8x8) - pad with zeros for unused cells
        for r in range(8):
            for c in range(8):
                if r < n and c < m:
                    dut.grid_in[r][c].value = grid_in[r][c]
                else:
                    dut.grid_in[r][c].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read and verify output
        for r in range(n):
            for c in range(m):
                if not is_value_defined(dut.grid_out[r][c].value):
                    raise TestFailure(f"Undefined output at [{r}][{c}]")
                actual = int(dut.grid_out[r][c].value)
                exp = expected[r][c]
                if actual != exp:
                    raise TestFailure(
                        f"Case {i+1} pos [{r}][{c}]: expected {exp}, got {actual}"
                    )
        
        dut._log.info(f"  PASS")
        await RisingEdge(dut.clk)  # Buffer between tests
    
    dut._log.info("All tests passed!")
