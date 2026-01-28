import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# Configuration
DATA_WIDTH = 20
MAX_TERMS = 8
CLK_PERIOD_NS = 10

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

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

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def parse_rebus(rebus_str):
    """Parse rebus string into positive/negative counts and n."""
    tokens = rebus_str.strip().split()
    n = int(tokens[-1])
    
    # Count operators
    num_plus = tokens.count('+')
    num_minus = tokens.count('-')
    
    # First term is always positive
    num_positive = num_plus + 1
    num_negative = num_minus
    
    # Extract operator sequence for reconstruction
    operators = [tok for tok in tokens if tok in ['+', '-']]
    
    return num_positive, num_negative, n, operators

async def reconstruct_rebus(operators, pos_terms, neg_terms, n):
    """Reconstruct the rebus string from operator sequence and terms."""
    output = []
    pos_idx = 0
    neg_idx = 0
    
    # First term is always positive
    output.append(str(pos_terms[pos_idx]))
    pos_idx += 1
    
    for op in operators:
        output.append(op)
        if op == '+':
            output.append(str(pos_terms[pos_idx]))
            pos_idx += 1
        else:  # '-'
            output.append(str(neg_terms[neg_idx]))
            neg_idx += 1
    
    output.append('=')
    output.append(str(n))
    return ' '.join(output)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_rebus_solver(dut):
    """Main test for rebus solver."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Get all test cases from the inputs and outputs
    inputs = [
        "? + ? - ? + ? + ? = 42",
        "? - ? = 1",
        "? = 1000000",
        "? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? = 9",
        "? - ? + ? + ? + ? + ? - ? - ? - ? - ? + ? - ? - ? - ? + ? - ? + ? + ? + ? - ? + ? + ? + ? - ? + ? + ? - ? + ? - ? + ? - ? - ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? + ? - ? + ? + ? - ? - ? - ? - ? + ? - ? - ? + ? + ? - ? + ? + ? - ? - ? - ? + ? + ? - ? - ? + ? - ? - ? + ? - ? + ? - ? - ? - ? - ? + ? - ? + ? - ? + ? + ? + ? - ? + ? + ? - ? - ? + ? = 123456",
        "? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? = 93",
        "? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? = 57",
        "? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? = 32",
        "? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? = 31",
        "? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? + ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? + ? + ? - ? - ? - ? + ? - ? + ? - ? - ? - ? - ? - ? + ? - ? + ? - ? - ? - ? - ? - ? - ? + ? - ? + ? - ? + ? - ? - ? + ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? + ? - ? - ? - ? + ? - ? + ? - ? - ? = 4",
        "? + ? - ? - ? - ? + ? + ? - ? + ? + ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? + ? - ? - ? - ? + ? - ? - ? - ? + ? - ? - ? - ? - ? - ? + ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? + ? - ? - ? - ? + ? - ? - ? + ? - ? + ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? = 5",
        "? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? - ? + ? - ? + ? + ? + ? + ? + ? + ? + ? - ? - ? + ? + ? + ? + ? + ? - ? - ? + ? + ? - ? + ? - ? - ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? - ? - ? + ? + ? + ? + ? - ? + ? + ? + ? - ? + ? - ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? = 3",
        "? + ? + ? + ? + ? + ? + ? + ? - ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? - ? - ? + ? + ? - ? - ? + ? + ? + ? - ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? - ? + ? + ? + ? - ? + ? + ? - ? - ? + ? - ? + ? + ? + ? = 4",
        "? + ? - ? + ? + ? - ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? - ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? - ? + ? - ? + ? - ? + ? + ? + ? + ? + ? + ? - ? + ? - ? - ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? - ? + ? + ? + ? + ? + ? + ? - ? + ? + ? - ? - ? + ? + ? = 4",
        "? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? = 100",
        "? + ? + ? - ? + ? - ? - ? - ? - ? - ? + ? - ? + ? + ? - ? + ? - ? + ? + ? - ? + ? - ? + ? + ? + ? - ? - ? - ? + ? - ? - ? + ? - ? - ? + ? - ? + ? + ? - ? + ? - ? - ? + ? + ? - ? - ? - ? + ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? + ? - ? - ? + ? - ? - ? - ? - ? + ? + ? - ? + ? + ? - ? + ? - ? + ? - ? + ? - ? - ? - ? - ? - ? + ? - ? = 837454",
        "? - ? + ? - ? + ? + ? - ? + ? - ? + ? + ? - ? + ? - ? - ? + ? - ? - ? + ? - ? + ? - ? - ? - ? - ? - ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? - ? - ? + ? - ? + ? + ? - ? + ? - ? + ? - ? - ? + ? - ? - ? + ? - ? - ? - ? + ? - ? - ? + ? - ? + ? + ? - ? - ? + ? - ? - ? + ? + ? - ? + ? - ? + ? + ? + ? + ? + ? - ? - ? + ? - ? - ? - ? + ? = 254253",
        "? - ? + ? + ? - ? + ? - ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? - ? + ? + ? - ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? - ? + ? + ? - ? + ? - ? + ? + ? + ? + ? + ? + ? - ? + ? - ? + ? - ? + ? + ? + ? + ? + ? + ? - ? + ? - ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? - ? - ? - ? + ? - ? + ? + ? + ? + ? - ? - ? + ? + ? - ? - ? + ? = 1000000",
        "? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? = 43386",
        "? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? = 999999",
        "? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? = 37",
        "? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? + ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? - ? = 19",
        "? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? - ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? = 15",
        "? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? + ? = 33",
        "? + ? + ? + ? + ? - ? = 3",
        "? + ? + ? + ? - ? = 2",
        "? + ? - ? + ? + ? = 2",
        "? + ? + ? + ? + ? - ? - ? = 2",
        "? - ? = 1",
        "? - ? + ? - ? + ? + ? + ? + ? = 2",
        "? + ? + ? + ? + ? + ? + ? + ? + ? + ? - ? = 5"
    ]
    
    outputs = [
        "Possible\n1 + 1 - 1 + 1 + 40 = 42\n",
        "Impossible\n",
        "Possible\n1000000 = 1000000\n",
        "Impossible\n",
        "Possible\n1 - 1 + 1 + 1 + 1 + 1 - 1 - 1 - 1 - 1 + 1 - 1 - 1 - 1 + 1 - 1 + 1 + 1 + 1 - 1 + 1 + 1 + 1 - 1 + 1 + 1 - 1 + 1 - 1 + 1 - 1 - 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 1 + 1 + 1 + 1 + 1 - 1 - 1 - 1 + 1 - 1 - 1 - 1 - 1 - 1 - 1 + 1 - 1 + 1 + 1 - 1 - 1 - 1 - 1 + 1 - 1 - 1 + 1 + 1 - 1 + 1 + 1 - 1 - 1 - 1 + 1 + 1 - 1 - 1 + 1 - 1 - 1 + 1 - 1 + 1 - 1 - 1 - 1 - 1 + 1 - 1 + 1 - 1 + 1 + 1 + 1 - 1 + 1 + 2 - 1 - 1 + 123456 = 123456\n",
        "Impossible\n",
        "Possible\n18 - 1 + 57 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 = 57\n",
        "Possible\n32 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 32 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 32 - 1 - 1 - 1 - 1 + 32 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 = 32\n",
        "Impossible\n",
        "Impossible\n",
        "Possible\n1 + 1 - 1 - 1 - 1 + 1 + 2 - 1 + 5 + 5 - 1 - 1 - 1 - 1 - 1 - 1 + 5 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 5 - 1 - 1 - 1 - 1 + 5 - 1 - 1 - 1 + 5 - 1 - 1 - 1 + 5 - 1 - 1 - 1 - 1 - 1 + 5 - 1 - 1 - 1 + 5 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 5 - 1 - 1 - 1 + 5 - 1 - 1 - 1 + 5 - 1 - 1 + 5 - 1 + 5 - 1 - 1 - 1 - 1 + 5 - 1 - 1 - 1 - 1 - 1 - 1 + 5 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 = 5\n",
        "Impossible\n",
        "Possible\n1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 4 - 4 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 4 + 1 + 1 - 4 - 4 + 1 + 1 - 4 - 4 + 1 + 1 + 1 - 4 - 4 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 4 + 1 + 1 + 1 - 4 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 4 + 1 + 1 + 1 + 1 + 1 + 1 - 4 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 4 - 4 + 1 + 1 + 1 - 4 + 1 + 1 - 4 - 4 + 1 - 4 + 1 + 1 + 1 = 4\n",
        "Possible\n1 + 1 - 1 + 1 + 1 - 3 + 1 + 1 + 1 - 4 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 4 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 4 + 1 + 1 - 4 + 1 + 1 - 4 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 4 + 1 + 1 + 1 + 1 - 4 + 1 - 4 + 1 - 4 + 1 + 1 + 1 + 1 + 1 + 1 - 4 + 1 - 4 - 4 - 4 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 4 + 1 - 4 + 1 + 1 + 1 + 1 + 1 + 1 - 4 + 1 + 1 - 4 - 4 + 1 + 1 = 4\n",
        "Possible\n1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 = 100\n",
        "Possible\n1 + 1 + 1 - 1 + 1 - 1 - 1 - 1 - 1 - 1 + 1 - 1 + 1 + 1 - 1 + 1 - 1 + 1 + 1 - 1 + 1 - 1 + 1 + 1 + 1 - 1 - 1 - 1 + 1 - 1 - 1 + 1 - 1 - 1 + 1 - 1 + 1 + 1 - 1 + 1 - 1 - 1 + 1 + 1 - 1 - 1 - 1 + 1 - 1 - 1 - 1 + 1 - 1 - 1 - 1 + 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 1 - 1 + 1 - 1 - 1 + 1 - 1 - 1 - 1 - 1 + 1 + 1 - 1 + 1 + 1 - 1 + 1 - 1 + 1 - 1 + 28 - 1 - 1 - 1 - 1 - 1 + 837454 - 1 = 837454\n",
        "Possible\n1 - 1 + 1 - 1 + 1 + 1 - 1 + 1 - 1 + 1 + 1 - 1 + 1 - 1 - 1 + 1 - 1 - 1 + 1 - 1 + 1 - 1 - 1 - 1 - 1 - 1 + 1 - 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 1 - 1 + 1 - 1 + 1 + 1 - 1 + 1 - 1 + 1 - 1 - 1 + 1 - 1 - 1 + 1 - 1 - 1 - 1 + 1 - 1 - 1 + 1 - 1 + 1 + 1 - 1 - 1 + 1 - 1 - 1 + 1 + 1 - 1 + 1 - 1 + 1 + 1 + 1 + 1 + 1 - 1 - 1 + 2 - 1 - 1 - 1 + 254253 = 254253\n",
        "Possible\n1 - 1 + 1 + 1 - 1 + 1 - 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 1 + 1 + 1 - 1 + 1 + 1 - 1 + 1 + 1 - 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 1 + 1 - 1 + 1 + 1 - 1 + 1 - 1 + 1 + 1 + 1 + 1 + 1 + 1 - 1 + 1 - 1 + 1 - 1 + 1 + 1 + 1 + 1 + 1 + 1 - 1 + 1 - 1 + 1 + 1 + 1 + 1 - 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 1 - 1 - 1 + 1 - 1 + 1 + 1 + 1 + 1 - 1 - 1 + 1 + 1 - 1 - 1 + 999963 = 1000000\n",
        "Impossible\n",
        "Possible\n98 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 999999 - 1 - 1 = 999999\n",
        "Possible\n1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 20 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 37 - 1 - 1 - 1 + 37 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 37 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 = 37\n",
        "Possible\n1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 11 - 1 - 1 - 1 - 1 - 1 - 1 + 19 - 1 - 1 - 1 - 1 - 1 - 1 + 19 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 + 19 - 1 - 1 - 1 - 1 + 19 - 1 - 1 - 1 - 1 - 1 + 19 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 = 19\n",
        "Possible\n1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 14 + 1 + 1 - 15 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 15 + 1 - 15 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 15 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 = 15\n",
        "Possible\n1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 33 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 = 33\n",
        "Possible\n1 + 1 + 1 + 1 + 1 - 2 = 3\n",
        "Possible\n1 + 1 + 1 + 1 - 2 = 2\n",
        "Possible\n1 + 1 - 2 + 1 + 1 = 2\n",
        "Possible\n1 + 1 + 1 + 1 + 1 - 1 - 2 = 2\n",
        "Impossible\n",
        "Possible\n1 - 2 + 1 - 2 + 1 + 1 + 1 + 1 = 2\n",
        "Possible\n1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 - 5 = 5\n"
    ]
    
    # Run all test cases
    for i, (rebus_input, expected_output) in enumerate(zip(inputs, outputs)):
        dut._log.info(f"Test {i+1}: {rebus_input}")
        
        # Parse the rebus input
        num_positive, num_negative, n, operators = await parse_rebus(rebus_input)
        
        # Skip if term counts exceed our limits
        if num_positive > MAX_TERMS or num_negative > MAX_TERMS:
            dut._log.warning(f"Test {i+1} skipped: too many terms ({num_positive} pos, {num_negative} neg)")
            continue
        
        # Set inputs
        dut.num_positive.value = num_positive
        dut.num_negative.value = num_negative
        dut.n.value = n
        
        # Start computation
        await start_computation(dut)
        
        # Wait for completion
        await wait_for_done(dut, max_cycles=1000)
        
        # Check if possible
        if not is_value_defined(dut.possible.value):
            raise TestFailure(f"Test {i+1}: possible signal undefined")
        
        actual_possible = bool(int(dut.possible.value))
        expected_possible = 'Possible' in expected_output
        
        if actual_possible != expected_possible:
            raise TestFailure(f"Test {i+1}: expected {'Possible' if expected_possible else 'Impossible'}, got {'Possible' if actual_possible else 'Impossible'}")
        
        # If possible, verify the solution
        if actual_possible:
            # Read terms
            pos_terms = []
            neg_terms = []
            
            for j in range(MAX_TERMS):
                if j < num_positive:
                    pos_terms.append(safe_int(dut.positive_terms[j].value))
                if j < num_negative:
                    neg_terms.append(safe_int(dut.negative_terms[j].value))
            
            # Verify constraints
            for val in pos_terms:
                if val < 1 or val > n:
                    raise TestFailure(f"Test {i+1}: Positive term {val} out of range [1, {n}]")
            for val in neg_terms:
                if val < 1 or val > n:
                    raise TestFailure(f"Test {i+1}: Negative term {val} out of range [1, {n}]")
            
            # Verify equation
            actual_sum = sum(pos_terms) - sum(neg_terms)
            if actual_sum != n:
                raise TestFailure(f"Test {i+1}: Equation failed: {sum(pos_terms)} - {sum(neg_terms)} = {actual_sum}, expected {n}")
            
            # Verify reconstruction
            reconstructed = await reconstruct_rebus(operators, pos_terms, neg_terms, n)
            if reconstructed != expected_output.strip().split('\n')[1]:
                dut._log.warning(f"Test {i+1}: Reconstructed '{reconstructed}' differs from expected '{expected_output.strip().split(chr(10))[1]}'")
        
        dut._log.info(f"Test {i+1}: PASS")
    
    dut._log.info("All tests completed!")