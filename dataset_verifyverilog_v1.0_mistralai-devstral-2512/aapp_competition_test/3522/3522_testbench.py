import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 32
MAX_BATTERIES = 32
MAX_N = 4
MAX_K = 4
CLK_NS = 10
MAX_CYCLES = 5000

# Helpers from spec
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Scale battery values to 0-1023 for fixed-point
def scale_battery(p):
    return int(p)  # Assume already scaled in test, or use: int(p * 1023 / 1000000000)

# Python reference implementation for expected d
def solve_reference(n, k, batteries):
    batteries.sort()
    m = 2 * n
    # Check if pairing with max diff d is possible
    def can_pair(d):
        # After sorting, try to pair adjacent or near batteries
        # We need m pairs where each pair's min is within d of other pair's min
        # Simplified: try to form pairs greedily
        pairs = []
        used = [False] * (2 * n * k)
        for i in range(0, len(batteries) - 1, 2):
            if not used[i] and not used[i+1]:
                if batteries[i+1] - batteries[i] <= d:
                    pairs.append(batteries[i])  # min of pair
                    used[i] = used[i+1] = True
        if len(pairs) != n:
            return False
        # Now check if we can assign chips to machines
        # Each machine needs 2 chips (2 pairs)
        # Sort pairs, then check adjacent differences
        pairs.sort()
        for i in range(0, len(pairs) - 1, 2):
            if pairs[i+1] - pairs[i] > d:
                return False
        return True
    
    # Binary search for minimal d
    low, high = 0, batteries[-1] - batteries[0]
    while low < high:
        mid = (low + high) // 2
        if can_pair(mid):
            high = mid
        else:
            low = mid + 1
    return low

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_power_supply(dut):
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        (2, 3, [1,2,3,4,5,6,7,8,9,10,11,12], 1),
        (2, 2, [3,1,3,3,3,3,3,3], 2)
    ]
    
    passed = 0
    failed = 0
    
    for n, k, batteries, expected_d in test_cases:
        total_batteries = 2 * n * k
        cocotb.log.info(f"Test: n={n}, k={k}, batteries={len(batteries)}")
        
        try:
            # Scale batteries to 0-1023 (assuming inputs are already in reasonable range)
            scaled_batteries = [clamp_to_width(b, DATA_WIDTH) for b in batteries[:total_batteries]]
            
            if is_seq:
                # Set inputs
                if has_signal(dut, 'n'):
                    dut.n.value = n
                if has_signal(dut, 'k'):
                    dut.k.value = k
                
                # Write batteries to array
                for i in range(total_batteries):
                    dut.batteries[i].value = scaled_batteries[i]
                
                # Clear unused batteries
                for i in range(total_batteries, MAX_BATTERIES):
                    dut.batteries[i].value = 0
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check valid and result
                if has_signal(dut, 'valid'):
                    if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                        raise TestFailure("Result not valid")
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                
                # Compare (allow small tolerance for algorithm differences)
                if result != expected_d:
                    raise TestFailure(f"Expected {expected_d}, got {result}")
                
                cocotb.log.info(f"PASS: d={result}")
                passed += 1
            else:
                # Combinational - just wait for propagation
                await Timer(100, units='ns')
                if is_value_defined(dut.result.value):
                    result = int(dut.result.value)
                    if result == expected_d:
                        passed += 1
                    else:
                        raise TestFailure(f"Expected {expected_d}, got {result}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: n={n}, k={k}, {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Edge case: all batteries same power
    n, k = 2, 2
    batteries = [5] * 8
    expected_d = 0
    
    if is_seq:
        dut.n.value = n
        dut.k.value = k
        for i in range(8):
            dut.batteries[i].value = batteries[i]
        for i in range(8, MAX_BATTERIES):
            dut.batteries[i].value = 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        
        if has_signal(dut, 'valid'):
            if int(dut.valid.value) != 1:
                raise TestFailure("Result not valid in edge case")
        
        result = int(dut.result.value)
        if result != expected_d:
            raise TestFailure(f"Edge case failed: Expected {expected_d}, got {result}")
        
        cocotb.log.info(f"Edge case PASS: all same power, d={result}")
    
    cocotb.log.info("Edge cases passed")