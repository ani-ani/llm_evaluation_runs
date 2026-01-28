import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
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

def pack_edges(edges, max_edges=64):
    """Pack list of (src, dst) tuples into a list of 8-bit integers."""
    packed = []
    for i in range(max_edges):
        if i < len(edges):
            src, dst = edges[i]
            # 0-indexed for hardware
            packed.append((src << 4) | dst)
        else:
            packed.append(0)
    return packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_governor_unification(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test Cases: (n, m, parties, edges, expected_months)
    # Partied and Edges are 0-indexed for hardware mapping
    test_cases = [
        {
            "n": 4, "m": 3,
            "parties": [0, 1, 0, 0], # 0=Orange, 1=Purple
            "edges": [(0, 1), (1, 2), (1, 3)], # 1-2 becomes 1-2 in 0-index
            "expected": 1
        },
        {
            "n": 5, "m": 4,
            "parties": [0, 1, 1, 0, 1],
            "edges": [(0, 1), (1, 2), (2, 3), (3, 4)],
            "expected": 2
        },
        {
            "n": 1, "m": 0,
            "parties": [0],
            "edges": [],
            "expected": 0
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: n={tc['n']}, expected={tc['expected']}")
        
        # Write Party Data
        party_val = 0
        for idx, p in enumerate(tc['parties']):
            party_val |= (p << idx)
        dut.party.value = party_val
        
        # Write Edge Data
        packed = pack_edges(tc['edges'])
        if has_signal(dut, 'edge_data'):
            for idx, val in enumerate(packed):
                # Check if edge_data is an array or a flattened vector
                try:
                    # Try array access
                    dut.edge_data[idx].value = val
                except (AttributeError, IndexError):
                    # Fallback to flattened logic if needed, or just log
                    cocotb.log.warning(f"Could not write edge_data[{idx}]")
        
        if has_signal(dut, 'num_edges'):
            dut.num_edges.value = tc['m']

        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        await wait_for_done(dut)

        # Check result
        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
            raise TestFailure(f"Test {i+1} Failed: Expected {expected}, got {result}")
        else:
            cocotb.log.info(f"Test {i+1} Passed: Result {result}")
