import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
CLK_NS = 10
MAX_CYCLES = 20000
MOD = 10**9 + 7

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Python Reference Implementation for Test Verification
def calculate_reference(n, color_matrix):
    # The problem implies a specific graph structure where f(S) is computable.
    # Given the constraint 'every cycle has adjacent same-colored edges', 
    # the graph is likely a 'Gallai coloring' or similar.
    # However, for n<=16, we can brute force f(S) for the test cases.
    # f(S) = max size of subset T in S such that all edges in T are same color.
    
    # Precompute clique info for all subsets to speed up
    # 1 << n subsets
    num_subsets = 1 << n
    
    # f_values[S] stores f(S)
    f_values = [0] * num_subsets
    
    # Iterate over all subsets S (excluding empty set)
    for s_mask in range(1, num_subsets):
        # Find max monochromatic clique size in S
        max_f = 0
        
        # Iterate over all submasks K of S to check if K is a monochromatic clique
        k = s_mask
        while k > 0:
            # Check if nodes in K form a monochromatic clique
            # Extract nodes in k
            nodes = [i for i in range(n) if (k >> i) & 1]
            
            if len(nodes) == 1:
                # Single node is a monochromatic clique (size 1)
                if len(nodes) > max_f:
                    max_f = len(nodes)
            else:
                # Check edges
                # Get color of first edge
                first_edge_color = 0
                valid = True
                for i in range(len(nodes)):
                    for j in range(i + 1, len(nodes)):
                        u, v = nodes[i], nodes[j]
                        color = color_matrix[u][v]
                        if i == 0 and j == 1:
                            first_edge_color = color
                        elif color != first_edge_color:
                            valid = False
                            break
                    if not valid: break
                
                if valid:
                    if len(nodes) > max_f:
                        max_f = len(nodes)
            
            # Iterate to next submask
            k = (k - 1) & s_mask
            
        f_values[s_mask] = max_f
        
    # Sum all f(S)
    total_sum = sum(f_values) % MOD
    return total_sum

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_graph_subset_max_clique(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic (unlikely for this problem)
        await Timer(100, units='ns')
    
    # Define test cases based on prompt examples
    # Case 1: n=4
    # 0 1 1 1
    # 1 0 2 2
    # 1 2 0 3
    # 1 2 3 0
    test_inputs = [
        {
            'n': 4,
            'matrix': [
                [0, 1, 1, 1],
                [1, 0, 2, 2],
                [1, 2, 0, 3],
                [1, 2, 3, 0]
            ],
            'expected': 26
        },
        {
            'n': 5,
            'matrix': [
                [0, 300, 300, 300, 300],
                [300, 0, 300, 300, 300],
                [300, 300, 0, 300, 300],
                [300, 300, 300, 0, 300],
                [300, 300, 300, 300, 0]
            ],
            'expected': 80
        }
    ]
    
    for idx, tc in enumerate(test_inputs):
        cocotb.log.info(f"Running Test Case {idx+1}: n={tc['n']}")
        
        # Reset before new input
        if has_signal(dut, 'rst_n'):
             await reset_dut(dut)
        
        # Set inputs
        if has_signal(dut, 'n'):
            dut.n.value = tc['n']
        
        # Set color matrix
        # Assuming interface is a flattened array or separate signals
        # We try to access arr[y][x] or similar
        # The spec says: color_matrix: 16x16 array of 8-bit values
        try:
            for y in range(16):
                for x in range(16):
                    val = 0
                    if y < tc['n'] and x < tc['n']:
                        val = tc['matrix'][y][x]
                    # Clamp to 8 bits
                    val &= 0xFF
                    
                    # Access pattern depends on RTL definition
                    # Try dut.color_matrix[y][x]
                    dut.color_matrix[y][x].value = val
        except Exception as e:
            cocotb.log.warning(f"Could not access color_matrix as 2D array: {e}")
            # Try flat access: dut.color_matrix[i]
            try:
                for i in range(256):
                    y = i // 16
                    x = i % 16
                    val = 0
                    if y < tc['n'] and x < tc['n']:
                        val = tc['matrix'][y][x]
                    dut.color_matrix[i].value = val & 0xFF
            except Exception as e2:
                cocotb.log.error(f"Could not access color_matrix as flat array: {e2}")
                raise

        # Pulse start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=10000)
            
            # Check result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            result_val = int(dut.result.value)
            if result_val != tc['expected']:
                raise TestFailure(f"Case {idx+1}: Expected {tc['expected']}, got {result_val}")
            
            cocotb.log.info(f"Case {idx+1} Passed: {result_val}")
        else:
            # Combinational check
            await Timer(1000, units='ns')
            if has_signal(dut, 'result'):
                result_val = int(dut.result.value)
                if result_val != tc['expected']:
                    raise TestFailure(f"Case {idx+1} (Comb): Expected {tc['expected']}, got {result_val}")
            else:
                raise TestFailure("No start signal and no result signal found")
