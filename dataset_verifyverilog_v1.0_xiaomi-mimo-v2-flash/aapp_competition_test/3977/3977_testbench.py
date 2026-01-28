import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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

# Test logic for the Hongcow problem (scaled to n<=16)
def solve_hongcow(n, m, k, gov_nodes, edges):
    # Python reference implementation using Union-Find
    parent = list(range(n))
    size = [1] * n

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(x, y):
        root_x = find(x)
        root_y = find(y)
        if root_x != root_y:
            if size[root_x] < size[root_y]:
                root_x, root_y = root_y, root_x
            parent[root_y] = root_x
            size[root_x] += size[root_y]

    # Process edges
    for u, v in edges:
        union(u, v)

    # Find component sizes for government nodes
    gov_sizes = []
    gov_roots = set()
    for g in gov_nodes:
        if g < n:
            root = find(g)
            gov_sizes.append(size[root])
            gov_roots.add(root)
    
    if not gov_sizes:
        # No gov nodes or all out of range
        return 0

    max_gov_size = max(gov_sizes)
    
    # Calculate total possible edges in current components
    # Sum of C(size[root], 2) for unique roots in gov_roots
    unique_gov_roots = set()
    total_possible = 0
    for root in gov_roots:
        if root not in unique_gov_roots:
            unique_gov_roots.add(root)
            s = size[root]
            total_possible += s * (s - 1) // 2
    
    # The logic in the problem is slightly different from standard Dijkstra but the math holds.
    # We want to add as many edges as possible.
    # Strategy: Keep government components disconnected.
    # Add edges within each component (already done in total_possible if we consider current graph).
    # We need to add NEW edges.
    # Max edges in a component of size S is S*(S-1)/2.
    # Max edges in whole graph (disconnected components) is sum(S_i*(S_i-1)/2).
    # However, we can connect non-gov components to the LARGEST gov component.
    
    # Let's calculate the answer directly:
    # 1. Sum edges possible within every gov component: sum(S_g * (S_g - 1) / 2)
    # 2. Subtract existing edges in those components (approximate by m, simplified)
    #    Actually, standard solution logic:
    #    Calculate max edges if we merge all non-gov nodes into the largest gov component,
    #    but keep other gov components separate.
    
    non_gov_nodes = n
    gov_component_roots = []
    
    for g in gov_nodes:
        if g < n:
            root = find(g)
            if root not in gov_component_roots:
                gov_component_roots.append(root)
                non_gov_nodes -= size[root]

    # Size of largest gov component
    largest = 0
    for r in gov_component_roots:
        if size[r] > largest:
            largest = size[r]
    
    # Formula from accepted solutions:
    # Answer = (Sum of C(size, 2) for all gov components) - C(max_size, 2) + C(max_size + non_gov_nodes, 2) - m
    # This assumes we merge all non-gov nodes into the largest gov component.
    
    term1 = 0
    for r in gov_component_roots:
        s = size[r]
        term1 += s * (s - 1) // 2
        
    term2 = largest * (largest - 1) // 2
    term3 = (largest + non_gov_nodes) * (largest + non_gov_nodes - 1) // 2
    
    return term1 - term2 + term3 - m

@cocotb.test(timeout_time=2000, timeout_unit='ms')
async def test_hongcow_module(dut):
    # Configuration
    CLK_NS = 10
    MAX_CYCLES = 1000
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    if has_signal(dut, 'clk'):
        for _ in range(2):
            await RisingEdge(dut.clk)
    else:
        await Timer(20, units='ns')
        
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

    # Test cases
    test_cases = [
        # n, m, k, gov_nodes, edges
        (4, 1, 2, [1, 3], [(1, 2)]),
        (3, 3, 1, [2], [(1, 2), (1, 3), (2, 3)]),
        (6, 4, 2, [1, 4], [(1, 2), (2, 3), (4, 5), (5, 6)]),
        (5, 2, 3, [1, 3, 4], [(1, 5), (2, 4)]),
        (10, 5, 3, [1, 5, 9], [(1, 3), (1, 8), (2, 3), (8, 4), (5, 7)])
    ]

    for i, (n, m, k, gov_list, edges) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: n={n}, m={m}, k={k}")
        
        # Calculate expected result
        expected = solve_hongcow(n, m, k, gov_list, edges)
        cocotb.log.info(f"Expected result: {expected}")

        # Drive Inputs
        dut.n.value = n
        dut.m.value = m
        dut.k.value = k
        
        # Set gov nodes (array of 16)
        if has_signal(dut, 'gov_nodes'):
            for idx in range(16):
                val = gov_list[idx] if idx < len(gov_list) else 0
                # Convert to 0-based if HDL expects 0-based, or 1-based if spec says so.
                # The Python code uses 0-based internally usually (x-1).
                # Let's assume HDL uses 0-based indexing for simplicity.
                dut.gov_nodes[idx].value = clamp_to_width(val - 1, 4) if val > 0 else 0
        
        # Set edges (dynamic input assumed for simplicity, or filled arrays)
        # If inputs are arrays (edges_u[0:15], edges_v[0:15]):
        if has_signal(dut, 'edges_u') and has_signal(dut, 'edges_v'):
            for idx in range(min(m, 16)): # Limit to array size for this test
                u, v = edges[idx]
                dut.edges_u[idx].value = u - 1
                dut.edges_v[idx].value = v - 1

        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_NS, units='ns')
            dut.start.value = 0
        else:
            # Combinational logic trigger
            await Timer(CLK_NS * 10, units='ns')

        # Wait for done
        if has_signal(dut, 'done'):
            done_count = 0
            for _ in range(MAX_CYCLES):
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(CLK_NS, units='ns')
                
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_count += 1
                    break
            
            if done_count == 0:
                raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        else:
            # If no done signal, just wait a bit for logic to settle
            await Timer(100, units='ns')

        # Read result
        if has_signal(dut, 'result'):
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Test {i+1}: Result signal is undefined")
            
            result = int(dut.result.value)
            cocotb.log.info(f"Test {i+1}: Got result {result}")
            
            if result != expected:
                raise TestFailure(f"Test {i+1}: Result mismatch. Expected {expected}, got {result}")
        else:
            raise TestFailure("Result signal not found")

    cocotb.log.info("All tests passed!")
