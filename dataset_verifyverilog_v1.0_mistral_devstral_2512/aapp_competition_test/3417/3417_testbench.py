import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def pack_edges(edges):
    packed = 0
    for i, (u, v) in enumerate(edges):
        u0 = u - 1
        v0 = v - 1
        packed |= ((u0 << 4) | v0) << (i * 8)
    return packed

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_mis_finder(dut):
    for sig in ['clk', 'rst_n', 'start', 'n', 'm', 'edges_packed', 'result', 'done']:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing signal: {sig}")
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        {"name": "Two vertices, one edge", "n": 2, "m": 1, "edges": [(1, 2)], "expected": 1},
        {"name": "Square with diagonal", "n": 4, "m": 5, "edges": [(1, 2), (2, 3), (3, 4), (4, 1), (1, 3)], "expected": 2},
        {"name": "Triangle", "n": 3, "m": 3, "edges": [(1, 2), (2, 3), (3, 1)], "expected": 1},
        {"name": "Path of 4", "n": 4, "m": 3, "edges": [(1, 2), (2, 3), (3, 4)], "expected": 2}
    ]
    
    passed = failed = 0
    
    for i, case in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {case['name']}")
        
        dut.n.value = case['n']
        dut.m.value = case['m']
        dut.edges_packed.value = pack_edges(case['edges'])
        
        await RisingEdge(dut.clk)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 500:
                raise TestFailure(f"Timeout after {cycles} cycles")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        
        result = int(dut.result.value)
        expected = case['expected']
        
        if result == expected:
            dut._log.info(f"  PASS: result={result}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    
    dut._log.info(f"Results: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")