import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# GCD for reduction
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_magic_path(dut):
    # Setup
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases adapted for small N (8 max)
    test_cases = [
        # Case 1: N=2, edges (1-2), magics [3,4] -> path magic: 3/1=3, 4/1=4, (3*4)/2=6 -> min is 3/1
        {
            'n': 2,
            'magics': [float_to_fixed(3), float_to_fixed(4)],
            'edges': [[0,1], [1,0]],  # 0-indexed, undirected
            'exp_numer': 3,
            'exp_denom': 1,
            'desc': 'Two nodes'
        },
        # Case 2: N=5, tree: 1-2-4, 1-3, 2-5; magics [2,1,1,1,3]
        # Paths: 2/1=2, 1/1=1, (2*1)/2=1, (1*1)/2=0.5, (2*1*1)/3=0.66, (2*1*3)/3=2, etc.
        # Min is 1/2 (path 1-3 or 4-? actually 1-3: magic 1/1=1, 2-4: 1/2=0.5, 2-5: 3/2=1.5, 1-2-4: (2*1*1)/3=0.66)
        # So 1/2 is correct from sample (path 2-4: magics 1 and 1 -> 1/2)
        {
            'n': 5,
            'magics': [float_to_fixed(2), float_to_fixed(1), float_to_fixed(1), float_to_fixed(1), float_to_fixed(3)],
            'edges': [
                [0,1], [1,0],
                [1,3], [3,1],
                [0,2], [2,0],
                [1,4], [4,1]
            ],
            'exp_numer': 1,
            'exp_denom': 2,
            'desc': 'Tree from sample'
        }
    ]

    passed = 0
    failed = 0

    for test in test_cases:
        cocotb.log.info(f"Running test: {test['desc']}")
        
        try:
            n = test['n']
            magics = test['magics']
            edges = test['edges']
            
            # Set num_nodes
            if has_signal(dut, 'num_nodes'):
                dut.num_nodes.value = n
            
            # Set node_magics (Q16.16)
            for i in range(n):
                # Access as array: dut.node_magic[i].value
                if hasattr(dut.node_magic, '__len__'):
                    dut.node_magic[i].value = magics[i]
                else:
                    # Packed or individual port, check
                    for j in range(8):
                        if hasattr(dut, f'node_magic_{j}'):
                            getattr(dut, f'node_magic_{j}').value = magics[i] if i == j else 0
                        else:
                            break
            
            # Set edges (adjacency matrix)
            # Assuming 8x8 matrix access
            for i in range(8):
                for j in range(8):
                    if hasattr(dut, f'edges_{i}_{j}'):
                        getattr(dut, f'edges_{i}_{j}').value = edges[i][j] if i < n and j < n else 0
                    elif hasattr(dut.edges, '__getitem__'):
                        if hasattr(dut.edges[i], '__getitem__'):
                            dut.edges[i][j].value = edges[i][j] if i < n and j < n else 0
                        else:
                            # Packed? assume individual for simplicity
                            pass
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            numer = int(dut.result_numer.value)
            denom = int(dut.result_denom.value)
            
            # Reduce expected fraction
            exp_numer = test['exp_numer']
            exp_denom = test['exp_denom']
            g = gcd(exp_numer, exp_denom)
            exp_numer_r = exp_numer // g
            exp_denom_r = exp_denom // g
            
            if numer != exp_numer_r or denom != exp_denom_r:
                raise TestFailure(f"Expected {exp_numer_r}/{exp_denom_r}, got {numer}/{denom}")
            
            passed += 1
            cocotb.log.info(f"PASS: {test['desc']} -> {numer}/{denom}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {test['desc']} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
