import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions (copied from template)
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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# Python reference implementation for small n, m
def count_ways_ref(n, m, p):
    # DP over columns
    dp_prev = [(0,0)] * (1 << n)
    for s in range(1 << n):
        cnt = bin(s).count('1')
        dp_prev[s] = (cnt, 1)  # (min, count)
    
    # Transition validity function
    def is_valid(prev, cur):
        for i in range(n-1):
            if ((prev >> i) & 3) == 0 and ((cur >> i) & 3) == 0:
                return False
        return True
    
    for col in range(1, m):
        dp_new = [(None,0) for _ in range(1 << n)]
        for cur in range(1 << n):
            pop = bin(cur).count('1')
            min_ob = 1000
            total_cnt = 0
            for prev in range(1 << n):
                if not is_valid(prev, cur):
                    continue
                ob, cnt = dp_prev[prev]
                ob += pop
                if ob < min_ob:
                    min_ob = ob
                    total_cnt = cnt
                elif ob == min_ob:
                    total_cnt = (total_cnt + cnt) % p
            dp_new[cur] = (min_ob, total_cnt % p)
        dp_prev = dp_new
    
    # Final answer
    min_ob = min(s[0] for s in dp_prev)
    total = sum(s[1] for s in dp_prev if s[0] == min_ob) % p
    return total

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_obstacles(dut):
    """Test the min_obstacles_counter module."""
    
    # Configure parameters (must match HDL)
    DATA_WIDTH = 8
    N_MAX = 8
    M_MAX = 16
    CLK_PERIOD = 10  # ns
    
    # Setup clock
    clock = Clock(dut.clk, CLK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    dut.p.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, m, p)
    test_cases = [
        (2, 2, 1000000007),   # 4
        (2, 3, 1000000007),   # 2
        (3, 2, 1000000007),   # ? (computed by reference)
        (4, 4, 999999937),    # 79 (from sample)
        (5, 5, 100000037),    # 1 (from sample)
    ]
    
    for n, m, p in test_cases:
        dut._log.info(f"Testing n={n}, m={m}, p={p}")
        
        # Compute reference
        expected = count_ways_ref(n, m, p)
        dut._log.info(f"Expected result: {expected}")
        
        # Provide inputs
        dut.n.value = n
        dut.m.value = m
        dut.p.value = p
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout_cycles = 100000  # Large timeout
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > timeout_cycles:
                raise TestFailure(f"Timeout waiting for done after {timeout_cycles} cycles")
        
        # Read result
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Result mismatch: expected {expected}, got {result}")
        else:
            dut._log.info(f"PASS: result = {result}")
    
    dut._log.info("All tests passed.")
