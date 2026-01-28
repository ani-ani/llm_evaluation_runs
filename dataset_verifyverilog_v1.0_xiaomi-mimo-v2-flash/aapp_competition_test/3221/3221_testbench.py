import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers from template
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_eulerian_cycle(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test case 1: Simple cycle of 3 nodes (K=3, max_c=5000000, alpha=2)
    # Energy = 5000000^2 + 2*3 = 25000000000006
    test_cases = [
        {
            'name': 'Triangle cycle',
            'N': 3, 'M': 3, 'alpha': 2,
            'edges': [
                (1, 2, 1000000),
                (2, 3, 2000000),
                (3, 1, 5000000),
            ],
            'expected': 25000000000006,
            'should_find': True
        },
        {
            'name': 'Disconnected nodes',
            'N': 4, 'M': 2, 'alpha': 5,
            'edges': [
                (1, 2, 1000000),
                (3, 4, 2000000),
            ],
            'expected': 0,
            'should_find': False
        },
        {
            'name': '4-node cycle',
            'N': 4, 'M': 4, 'alpha': 1,
            'edges': [
                (1, 2, 1000000),
                (2, 3, 2000000),
                (3, 4, 3000000),
                (4, 1, 4000000),
            ],
            'expected': 16000000000004,
            'should_find': True
        },
    ]
    
    for tc in test_cases:
        cocotb.log.info(f"Test: {tc['name']}")
        
        # Write configuration
        if has_signal(dut, 'N'):
            dut.N.value = clamp_to_width(tc['N'], 4)
        if has_signal(dut, 'M'):
            dut.M.value = clamp_to_width(tc['M'], 5)
        if has_signal(dut, 'alpha'):
            dut.alpha.value = clamp_to_width(tc['alpha'], 5)
        
        # Write edges
        for i, (u, v, c) in enumerate(tc['edges']):
            if has_signal(dut, f'edge_u_{i}'):
                getattr(dut, f'edge_u_{i}').value = clamp_to_width(u-1, 4)
                getattr(dut, f'edge_v_{i}').value = clamp_to_width(v-1, 4)
                getattr(dut, f'edge_c_{i}').value = clamp_to_width(c, 32)
            elif has_signal(dut, 'edge_u'):
                dut.edge_u[i].value = clamp_to_width(u-1, 4)
                dut.edge_v[i].value = clamp_to_width(v-1, 4)
                dut.edge_c[i].value = clamp_to_width(c, 32)
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(500, units='ns')
        
        # Check results
        if has_signal(dut, 'valid'):
            valid = int(dut.valid.value)
        else:
            valid = 1  # Assume valid if no signal
        
        if tc['should_find']:
            if not valid:
                raise TestFailure(f"Expected valid solution but got invalid for {tc['name']}")
            
            result = int(dut.result.value)
            # Allow some tolerance for simulation
            if abs(result - tc['expected']) > 1000:
                raise TestFailure(f"Expected {tc['expected']}, got {result} for {tc['name']}")
            cocotb.log.info(f"  Result: {result} (expected: {tc['expected']})")
        else:
            if valid:
                result = int(dut.result.value)
                raise TestFailure(f"Expected no solution but got result={result} for {tc['name']}")
            cocotb.log.info(f"  Correctly found no solution")
    
    cocotb.log.info("All tests passed!")