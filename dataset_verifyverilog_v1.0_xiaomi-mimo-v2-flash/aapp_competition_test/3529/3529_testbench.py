import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers

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

def pack_16x16(matrix):
    """Pack 16x16 2D list into 256-bit integer"""
    packed = 0
    for i in range(16):
        row = 0
        for j in range(16):
            if i < len(matrix) and j < len(matrix[i]) and matrix[i][j]:
                row |= (1 << j)
        packed |= (row << (16 * i))
    return packed

def parse_and_set_matrix(dut, name, adj_matrix, n):
    """Set adjacency matrix signals for given n nodes"""
    # Initialize full 16x16 matrix
    full_matrix = [[0]*16 for _ in range(16)]
    for i in range(n):
        for j in range(n):
            if i < len(adj_matrix) and j < len(adj_matrix[i]):
                full_matrix[i][j] = adj_matrix[i][j]
    
    # Try packed assignment first
    if has_signal(dut, name):
        packed = pack_16x16(full_matrix)
        dut.__getattr__(name).value = packed
    else:
        # Individual row assignment
        for i in range(16):
            row_val = 0
            for j in range(16):
                if full_matrix[i][j]:
                    row_val |= (1 << j)
            if has_signal(dut, f"{name}_{i}"):
                getattr(dut, f"{name}_{i}").value = row_val
            elif has_signal(dut, f"{name}[{i}]"):
                dut.__getattr__(f"{name}[{i}]").value = row_val

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_spanning_tree(dut):
    # Setup
    CLK_NS = 10
    MAX_CYCLES = 300
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            if has_signal(dut, 'start'):
                dut.start.value = 0
            for _ in range(3):
                await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    else:
        # Combinational circuit
        await Timer(100, units='ns')
    
    # Test cases based on examples
    test_cases = [
        {
            'desc': 'Example 1: 3 nodes, k=2, blue edges (1-2, 2-3), red (3-1)',
            'n': 3,
            'k': 2,
            'blue_adj': [[0,1,0], [1,0,1], [0,1,0]],
            'red_adj': [[0,0,1], [0,0,0], [1,0,0]],
            'expected': 1
        },
        {
            'desc': 'Example 2: 2 nodes, k=1, only red edge',
            'n': 2,
            'k': 1,
            'blue_adj': [[0,0],[0,0]],
            'red_adj': [[0,1],[1,0]],
            'expected': 0
        },
        {
            'desc': 'Small valid case: 2 nodes, k=0, blue edge exists',
            'n': 2,
            'k': 0,
            'blue_adj': [[0,1],[1,0]],
            'red_adj': [[0,0],[0,0]],
            'expected': 1
        },
        {
            'desc': '3 nodes, k=1, valid tree with 1 blue',
            'n': 3,
            'k': 1,
            'blue_adj': [[0,1,0],[1,0,0],[0,0,0]],
            'red_adj': [[0,0,1],[0,0,1],[1,1,0]],
            'expected': 1
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {tc['desc']}")
        
        # Set inputs
        if has_signal(dut, 'n'):
            dut.n.value = clamp_to_width(tc['n'], 4)
        if has_signal(dut, 'k'):
            dut.k.value = clamp_to_width(tc['k'], 4)
        
        # Set adjacency matrices
        parse_and_set_matrix(dut, 'blue_adj', tc['blue_adj'], tc['n'])
        parse_and_set_matrix(dut, 'red_adj', tc['red_adj'], tc['n'])
        
        if has_signal(dut, 'clk'):
            # Sequential logic
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done = False
            for cycle in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                cocotb.log.error(f"Test {i+1}: Timeout waiting for done")
                failed += 1
                continue
        else:
            # Combinational: wait for propagation
            await Timer(50, units='ns')
        
        # Check result
        if not has_signal(dut, 'result'):
            cocotb.log.error(f"Test {i+1}: No result signal found")
            failed += 1
            continue
            
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {i+1}: Result undefined")
            failed += 1
            continue
        
        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
            cocotb.log.error(f"Test {i+1}: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"Test {i+1}: PASS")
            passed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    cocotb.log.info(f"All {passed} tests passed!")
