import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 5
ARRAY_SIZE = 8
RESULT_WIDTH = 2
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Array access helpers
async def write_array(dut, array_name, values, element_width):
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

# Sequential helpers
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_election_solver(dut):
    """Test election solver module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        ("3 1 5 4\n1 2 1 3", [1, 3, 3]),
        ("3 1 5 3\n1 3 1", [2, 3, 2]),
        ("3 2 5 3\n1 3 1", [1, 2, 2]),
        ("1 1 1 1\n1", [1]),
        ("2 1 1 1\n2", [3, 1]),
        ("2 1 1 1\n1", [1, 3]),
        ("3 3 5 4\n1 2 3 2", [1, 1, 1]),
        ("4 2 1 1\n1", [1, 3, 3, 3]),
        ("5 5 1 1\n5", [3, 3, 3, 3, 1]),
        ("1 1 2 2\n1 1", [1]),
        ("2 2 3 3\n2 2 1", [1, 1]),
        ("4 2 3 2\n1 4", [1, 3, 3, 1]),
        ("3 1 3 2\n2 1", [3, 1, 3]),
        ("1 1 5 4\n1 1 1 1", [1]),
        ("2 2 6 6\n1 2 1 1 1 2", [1, 1]),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (input_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {input_str[:50]}...")
        
        # Parse input
        lines = input_str.strip().split('\n')
        first_line = lines[0].split()
        n, k, m, a = map(int, first_line)
        
        if len(lines) > 1:
            votes = list(map(int, lines[1].split()))
        else:
            votes = []
        
        # Compute vote counts and last vote times
        vote_count = [0] * 8
        last_vote = [32] * 8  # Initialize with high value for zero-vote candidates
        
        for t, cand in enumerate(votes):
            idx = cand - 1  # Convert to 0-indexed
            vote_count[idx] += 1
            last_vote[idx] = t
        
        # Set inputs
        dut.n.value = n
        dut.k.value = k
        dut.m.value = m
        dut.a.value = a
        
        # Write vote_count and last_vote arrays
        for i in range(8):
            dut.vote_count[i].value = clamp_to_width(vote_count[i], DATA_WIDTH)
            dut.last_vote[i].value = clamp_to_width(last_vote[i], DATA_WIDTH)
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read results
        results = []
        for i in range(8):
            if i < n:
                if is_value_defined(dut.result[i].value):
                    results.append(int(dut.result[i].value))
                else:
                    results.append(None)
            else:
                break
        
        # Verify
        try:
            if len(results) != len(expected):
                raise TestFailure(f"Expected {len(expected)} results, got {len(results)}")
            
            for i, (res, exp) in enumerate(zip(results, expected)):
                if res is None:
                    raise TestFailure(f"Result {i} is undefined")
                if res != exp:
                    raise TestFailure(f"Candidate {i}: expected {exp}, got {res}")
            
            cocotb.log.info(f"  PASS: {results}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")