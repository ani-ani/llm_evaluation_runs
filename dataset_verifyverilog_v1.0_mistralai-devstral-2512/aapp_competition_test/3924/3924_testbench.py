import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# MANDATORY HELPERS
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

# ARRAY ACCESS HELPER (Critical)
def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

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

# PYTHON REFERENCE IMPLEMENTATION
def solve_reference(n, k, a):
    bags = 0
    carry = 0
    for i in range(n):
        total = a[i] + carry
        if i == n - 1: # Last day
            # Must dispose everything
            # Bags = ceil(total / k)
            if total == 0:
                bags += 0
            else:
                bags += (total + k - 1) // k
            carry = 0
        else:
            # Can leave some for next day
            bags += total // k
            carry = total % k
    # Note: The logic in some solutions handles carry>0 after loop by adding 1 bag.
    # But if we handle last day correctly (must dispose all), carry should be 0.
    # However, the greedy logic sometimes leaves carry if we strictly only fill bags.
    # Let's re-read problem: "Each unit of garbage must be disposed of either on the day it was produced or on the next day."
    # This implies if carry > 0 after last day, we need another bag. 
    # The prompt's Python examples show `if val!=0: ans+=1` at end.
    # Let's stick to the prompt's common greedy approach:
    # Process days 0 to n-2. Last day (n-1) handles remaining.
    
    # Re-implementing the logic from the prompt's python codes (e.g. snippet 1)
    ans = a[0] // k
    val = a[0] % k
    for i in range(1, n):
        if val == 0:
            ans += a[i] // k
            val = a[i] % k
        else:
            val += a[i]
            if val < k:
                val = 0
                ans += 1
            else:
                ans += val // k
                val = val % k
    if val != 0:
        ans += 1
    return ans

class LazyDriver:
    def __init__(self, dut):
        self.dut = dut
        self.items = []
        self.ptr = 0
        
    def push(self, n, k, a_list):
        self.items.append((n, k, a_list))
        
    async def run_test(self, dut):
        for n, k, a_list in self.items:
            cocotb.log.info(f"Testing n={n}, k={k}, a={a_list[:5]}...")
            
            # Calculate expected
            exp = solve_reference(n, k, a_list)
            
            # Drive DUT
            dut.n.value = n
            dut.k.value = k
            
            # Start sequence
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed data stream
            for val in a_list:
                dut.a_in.value = val
                await RisingEdge(dut.clk)
                
            # Wait for done
            await wait_for_done(dut, max_cycles=n + 10)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            res = int(dut.result.value)
            if res != exp:
                raise TestFailure(f"Expected {exp}, got {res}")
            else:
                cocotb.log.info(f"Pass: {exp}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_garbage_disposal(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    driver = LazyDriver(dut)
    
    # Test Cases
    # 1. Basic from prompt
    driver.push(3, 2, [3, 2, 1])
    driver.push(3, 2, [1, 0, 1])
    driver.push(4, 4, [2, 8, 4, 1])
    
    # 2. Edge cases
    driver.push(1, 1, [0])
    driver.push(1, 1, [1])
    driver.push(1, 10, [0])
    driver.push(1, 10, [5])
    
    # 3. Small arrays
    driver.push(2, 3, [2, 7])
    driver.push(3, 6, [2, 3, 3])
    driver.push(4, 4, [3, 6, 2, 3])
    
    # 4. Large values (scaled to 10-bit)
    # Original had 10^9, here max 1023
    driver.push(5, 100, [100, 100, 100, 100, 100])
    
    await driver.run_test(dut)