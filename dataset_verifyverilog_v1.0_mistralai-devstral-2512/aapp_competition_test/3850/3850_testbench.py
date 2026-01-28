import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
DATA_WIDTH = 16
MAX_VAL = (1 << DATA_WIDTH) - 1
CLK_NS = 10

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    if v < 0: v = v + (1 << bits) # Treat as signed if needed, but problem uses positive
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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Test function to calculate expected result in Python
def calculate_expected(n, k, p, people, keys):
    people_sorted = sorted(people)
    keys_sorted = sorted(keys)
    min_time = float('inf')
    
    # Sliding window over sorted keys
    for i in range(k - n + 1):
        max_time = 0
        for j in range(n):
            # Distance: person -> key -> office
            dist = abs(people_sorted[j] - keys_sorted[i + j]) + abs(keys_sorted[i + j] - p)
            if dist > max_time:
                max_time = dist
        if max_time < min_time:
            min_time = max_time
    return int(min_time)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_keys_and_office(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test Cases: (n, k, p, people_list, keys_list, description)
    test_cases = [
        (2, 4, 50, [20, 100], [60, 10, 40, 80], "Example 1"),
        (1, 2, 10, [11], [15, 7], "Example 2"),
        (2, 5, 15, [10, 4], [29, 23, 21, 22, 26], "Case 3"),
        (2, 2, 4, [3, 4], [5, 6], "Edge: small distance"),
        (2, 2, 100, [99, 150], [1, 150], "Case: matching key"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, p, people, keys, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Calculate expected
            expected = calculate_expected(n, k, p, people, keys)
            
            # Input assignment
            if has_signal(dut, 'n'):
                dut.n.value = n
            if has_signal(dut, 'k'):
                dut.k.value = k
            if has_signal(dut, 'p'):
                dut.p.value = clamp_to_width(p, DATA_WIDTH)
            
            # People assignment (0 to 7)
            for idx in range(8):
                val = people[idx] if idx < n else 0
                # Handle array naming: people[0], people[1]...
                signal_name = f'people_{idx}'
                if has_signal(dut, signal_name):
                    getattr(dut, signal_name).value = clamp_to_width(val, DATA_WIDTH)
                else:
                    # Fallback for standard array syntax if available
                    dut.people[idx].value = clamp_to_width(val, DATA_WIDTH)

            # Keys assignment (0 to 15)
            for idx in range(16):
                val = keys[idx] if idx < k else 0
                signal_name = f'keys_{idx}'
                if has_signal(dut, signal_name):
                    getattr(dut, signal_name).value = clamp_to_width(val, DATA_WIDTH)
                else:
                    dut.keys[idx].value = clamp_to_width(val, DATA_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
                
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")