import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPER FUNCTIONS
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

# Constants
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Test case definitions (n ≤ 16, m ≤ 16)
test_cases = [
    {
        "input": "5 3\n1 3\n2 5\n4 5\n",
        "expected_min_length": 2,
        "expected_array": [0, 1, 0, 1, 0]
    },
    {
        "input": "4 2\n1 4\n2 4\n",
        "expected_min_length": 3,
        "expected_array": [0, 1, 2, 0]
    },
    {
        "input": "1 1\n1 1\n",
        "expected_min_length": 1,
        "expected_array": [0]
    },
    {
        "input": "3 3\n1 3\n2 2\n1 3\n",
        "expected_min_length": 1,
        "expected_array": [0, 0, 0]
    },
    {
        "input": "10 4\n4 10\n4 6\n6 8\n1 10\n",
        "expected_min_length": 3,
        "expected_array": [0, 1, 2, 0, 1, 2, 0, 1, 2, 0]
    }
]

def parse_test_case(input_str):
    lines = input_str.strip().split('\n')
    n, m = map(int, lines[0].split())
    queries = []
    for i in range(1, 1 + m):
        l, r = map(int, lines[i].split())
        queries.append((l, r))
    return n, m, queries

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_mex_optimizer(dut):
    """Test MinMexOptimizer module"""
    
    # Start clock
    clock = Clock(dut.clk, CLK_PERIOD_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.l_in.value = 0
    dut.r_in.value = 0
    dut.n.value = 0
    dut.m.value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Run test cases
    for idx, test_case in enumerate(test_cases):
        dut._log.info(f"Running test case {idx+1}")
        
        # Parse test case
        n, m, queries = parse_test_case(test_case["input"])
        
        # Set n and m
        dut.n.value = n
        dut.m.value = m
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed queries
        for l, r in queries:
            dut.valid_in.value = 1
            dut.l_in.value = l
            dut.r_in.value = r
            await RisingEdge(dut.clk)
        
        dut.valid_in.value = 0
        
        # Wait for done
        cycles = 0
        done = False
        while cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
            cycles += 1
        
        if not done:
            raise TestFailure(f"Test {idx+1}: Timeout waiting for done")
        
        # Check min_length
        dut_min_length = int(dut.min_length.value)
        if dut_min_length != test_case["expected_min_length"]:
            raise TestFailure(
                f"Test {idx+1}: min_length mismatch. "
                f"Expected {test_case['expected_min_length']}, got {dut_min_length}"
            )
        
        # Check array
        n = test_case["expected_min_length"]  # Use min_length to know expected pattern
        for i in range(len(test_case["expected_array"])):
            # Extract 4-bit element from packed array
            start_bit = i * 4
            element = (dut.result_array.value >> start_bit) & 0xF
            
            if element != test_case["expected_array"][i]:
                raise TestFailure(
                    f"Test {idx+1}: Array element {i} mismatch. "
                    f"Expected {test_case['expected_array'][i]}, got {element}"
                )
        
        dut._log.info(f"Test {idx+1} passed")
    
    dut._log.info("All tests passed!")