import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

MOD = 1000000007

def solve(names):
    """Python reference for the logic."""
    # Build Trie
    class Node:
        def __init__(self):
            self.children = {}
            self.end_count = 0
            self.size = 0
            self.ways = 1

    root = Node()
    
    # Factorials for small N
    fact = [1] * 10
    for i in range(1, 10):
        fact[i] = fact[i-1] * i

    # Modular inverse for factorials (brute force for small numbers)
    def modInverse(n, mod):
        return pow(n, mod - 2, mod)

    for name in names:
        node = root
        for char in name:
            if char not in node.children:
                node.children[char] = Node()
            node = node.children[char]
        node.end_count += 1

    def compute(node):
        if not node:
            return 0, 1 # size, ways
        
        # Collect children results
        child_sizes = []
        child_ways_prod = 1
        
        for char in sorted(node.children.keys()): # Deterministic order
            child = node.children[char]
            s, w = compute(child)
            child_sizes.append(s)
            child_ways_prod = (child_ways_prod * w) % MOD
        
        total_children_size = sum(child_sizes)
        
        # Multinomial coefficient
        # ways = fact[total_children_size] / (prod fact[child_size]) * fact[node.end_count] * prod(child_ways)
        
        numerator = fact[total_children_size]
        denominator = 1
        for s in child_sizes:
            denominator = (denominator * fact[s]) % MOD
        
        multinomial = (numerator * modInverse(denominator, MOD)) % MOD
        
        node.size = total_children_size + node.end_count
        node.ways = (multinomial * fact[node.end_count] * child_ways_prod) % MOD
        
        return node.size, node.ways

    _, final_ways = compute(root)
    return final_ways

# Test cases adaptation
# Original constraints: N=3000, name len=3000.
# Scaled constraints: N=8, name len=8.
# We will use small strings for the testbench.

test_cases = [
    (["IVO", "JASNA", "JOSIPA"], 4),
    (["MARICA", "MARTA", "MATO", "MARA", "MARTINA"], 24),
    (["A", "AA", "AAA", "AAAA"], 8),
    (["B", "A", "AA"], 3), # Simple test
]

# Adjusted for small N limit (8)
# We need to ensure inputs fit into the scaled constraints of the module (8 names, 8 chars).
# The first two cases fit. The third has max len 4, fits. Fourth fits.

@cocotb.test()
async def test_name_ranking(dut):
    """Test the Name Ranking Counter module."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_char.value = 0
    dut.char_in.value = 0
    dut.name_idx.value = 0
    dut.char_idx.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = 0
    
    for names, expected in test_cases:
        # Filter test cases if N > 8 or any name len > 8 (scale limit)
        if len(names) > 8 or any(len(n) > 8 for n in names):
            print(f"Skipping case {names} due to scaling constraints")
            continue
            
        total += 1
        print(f"Testing case: {names}, Expected: {expected}")
        
        # Load Data
        dut.start.value = 0
        for i, name in enumerate(names):
            for j, char in enumerate(name):
                dut.char_in.value = ord(char)
                dut.name_idx.value = i
                dut.char_idx.value = j
                dut.load_char.value = 1
                await RisingEdge(dut.clk)
                dut.load_char.value = 0
                await RisingEdge(dut.clk)
        
        # Fill remaining names/chars with 0 (or handle in design, assuming unused entries don't affect result)
        # In this testbench, we only load valid names.
        
        # Start Computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 5000 # Sufficient for the logic
        for _ in range(max_cycles):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        if dut.done.value != 1:
            raise TestFailure(f"Module did not finish in time for case {names}")
            
        result = int(dut.result.value)
        print(f"Got result: {result}")
        
        if result == expected:
            passed += 1
        else:
            raise TestFailure(f"Result mismatch: got {result}, expected {expected}")
            
    print(f"
{passed}/{total} tests passed")
