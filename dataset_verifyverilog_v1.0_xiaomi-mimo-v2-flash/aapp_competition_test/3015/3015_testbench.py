import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants based on spec
MAX_NODES = 16
MAX_EDGES = 32
DATA_WIDTH = 16
NODE_WIDTH = 4
EDGE_BITS = NODE_WIDTH + NODE_WIDTH + DATA_WIDTH  # 24
MAX_CYCLES = 256
CLK_NS = 10
INFINITY_SENTINEL = 0xFFFFFFFE

# Helpers
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES + 50):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Graph construction helpers
def pack_edge(src, dst, w):
    return (src << (NODE_WIDTH + DATA_WIDTH)) | (dst << DATA_WIDTH) | w

def parse_test_input(input_str):
    lines = input_str.strip().split('\n')
    n, m, s, t = map(int, lines[0].split())
    edges = []
    for i in range(1, 1 + m):
        u, v, w = map(int, lines[i].split())
        edges.append((u, v, w))
    return n, m, s, t, edges

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_hamster_maze(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases from prompt
    test_cases = [
        # Input string, Expected result (or "infinity")
        ("4 5 0 3\n0 1 1\n1 2 2\n2 0 4\n2 3 1\n2 3 3\n", "11"),
        ("5 5 0 4\n0 1 1\n1 2 1\n2 3 1\n3 0 1\n2 4 1\n", "infinity"),
        ("2 1 0 1\n0 1 2\n", "2"),
        ("3 3 1 2\n0 1 1\n1 0 1\n1 2 1\n", "infinity"),
        ("3 2 0 1\n0 2 3\n2 0 3\n", "infinity")
    ]

    passed = 0
    failed = 0

    for i, (inp_str, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        try:
            n, m, s, t, edges = parse_test_input(inp_str)
            
            # Validate constraints for hardware
            if n > MAX_NODES or m > MAX_EDGES:
                cocotb.log.info(f"Skipping case {i+1}: Graph too large for HW (n={n}, m={m})")
                continue

            # Clear inputs
            dut.start.value = 0
            dut.valid_edges.value = 0
            for k in range(MAX_EDGES):
                if has_signal(dut, f'edge_{k}'): 
                    getattr(dut, f'edge_{k}').value = 0
                elif has_signal(dut, 'edge_data') and has_signal(dut, 'edge_addr'):
                     # Assuming RAM interface if not indexed ports
                     pass
            
            # Handle array input format: assuming packed array or individual signals
            # We check if 'edge_data' exists for packed loading
            if has_signal(dut, 'edge_data') and has_signal(dut, 'edge_addr'):
                 # Ram-like interface not fully supported in this simple template, assume indexed ports
                 pass
            
            # Load edges into the module
            for edge_idx, (u, v, w) in enumerate(edges):
                packed = pack_edge(u, v, w)
                if has_signal(dut, f'edge_{edge_idx}'):
                    getattr(dut, f'edge_{edge_idx}').value = packed
                else:
                    # Fallback if signals are edge_data[0], edge_data[1]...
                    # But spec says flat array. Let's assume individual ports edge_0 to edge_31
                    pass
            
            # Set start and target (if inputs exist)
            if has_signal(dut, 'start_node'):
                dut.start_node.value = s
            if has_signal(dut, 'target_node'):
                dut.target_node.value = t
            
            dut.valid_edges.value = m
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if expected_str == "infinity":
                if result != INFINITY_SENTINEL:
                    raise TestFailure(f"Expected infinity (0x{INFINITY_SENTINEL:X}), got {result}")
            else:
                exp_val = int(expected_str)
                if result != exp_val:
                    raise TestFailure(f"Expected {exp_val}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
        finally:
             await reset_dut(dut)  # Reset for next test

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
