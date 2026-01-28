import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
N_WIDTH = 4
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def compute_expected(n, candies):
    # candies: list of (a, b) where a, b are 1-indexed stations
    # Convert to 0-indexed internally
    counts = [0] * n
    min_dists = [n] * n  # Initialize with max possible dist
    
    for a, b in candies:
        a -= 1
        b -= 1
        counts[a] += 1
        # Clockwise distance from a to b
        dist = (b - a) % n
        if dist < min_dists[a]:
            min_dists[a] = dist
            
    results = []
    for s in range(n):
        max_time = 0
        for i in range(n):
            if counts[i] > 0:
                dist_si = (i - s) % n
                time = dist_si + n * (counts[i] - 1) + min_dists[i]
                if time > max_time:
                    max_time = time
        results.append(max_time)
    return results

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_toy_train(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        {
            "n": 5,
            "m": 7,
            "candies": [(2,4), (5,1), (2,3), (3,4), (4,1), (5,3), (3,5)],
            "expected": [10, 9, 10, 10, 9]
        },
        {
            "n": 2,
            "m": 3,
            "candies": [(1,2), (1,2), (1,2)],
            "expected": [5, 6]
        },
        {
            "n": 5,
            "m": 1,
            "candies": [(3, 2)],
            "expected": [6, 5, 4, 8, 7]
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: n={tc['n']}, m={tc['m']}")
        
        # Pre-compute statistics
        counts = [0] * 16
        min_dists = [0] * 16  # Don't care if count is 0
        
        for a, b in tc['candies']:
            a -= 1
            b -= 1
            counts[a] += 1
            dist = (b - a) % tc['n']
            if counts[a] == 1 or dist < min_dists[a]:
                min_dists[a] = dist
        
        # Load inputs
        dut.n_in.value = clamp_to_width(tc['n'], N_WIDTH)
        
        for idx in range(16):
            # Access array elements individually
            if has_signal(dut, f'candy_count_{idx}'):
                getattr(dut, f'candy_count_{idx}').value = clamp_to_width(counts[idx], N_WIDTH)
                getattr(dut, f'min_dist_{idx}').value = clamp_to_width(min_dists[idx], N_WIDTH)
            else:
                # Packed array or other structure (using generic index access)
                dut.candy_count[idx].value = clamp_to_width(counts[idx], N_WIDTH)
                dut.min_dist[idx].value = clamp_to_width(min_dists[idx], N_WIDTH)
        
        # Start calculation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # If no start signal, assume combinational or triggered by clock edge
            await RisingEdge(dut.clk)
        
        # Wait for done
        try:
            if has_signal(dut, 'done'):
                await wait_for_done(dut, max_cycles=100)
            else:
                await Timer(500, units='ns') # Combinational or simple pipeline
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Timeout): {e}")
            failed += 1
            continue
            
        # Check results
        try:
            if tc['n'] > 0:
                results = []
                for idx in range(tc['n']):
                    if has_signal(dut, f'result_{idx}'):
                        val = int(getattr(dut, f'result_{idx}').value)
                    else:
                        val = int(dut.result[idx].value)
                    results.append(val)
                
                cocotb.log.info(f"Expected: {tc['expected']}")
                cocotb.log.info(f"Got:      {results}")
                
                if results != tc['expected']:
                    raise TestFailure(f"Result mismatch for start station {idx}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Check): {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
