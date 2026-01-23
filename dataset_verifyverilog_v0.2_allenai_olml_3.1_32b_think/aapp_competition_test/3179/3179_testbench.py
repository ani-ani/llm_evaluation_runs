import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

def to_fixed_q12_4(val):
    return int(val * 16) & 0xFFFF

def to_fixed_q16_16(val):
    return int(val * 65536) & 0xFFFFFFFF

def from_fixed_q16_16(val):
    if val & 0x80000000:
        return (val - 0x100000000) / 65536.0
    return val / 65536.0

@cocotb.test()
async def test_canyon_map_solver(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_vertices.value = 0
    dut.k.value = 0
    for i in range(16):
        dut.poly_x[i].value = 0
        dut.poly_y[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Case 1: 4 vertices, k=1
        {
            'verts': [(1,1), (5,1), (5,5), (4,2)],
            'k': 1,
            'expected': 4.0
        },
        # Case 2: 6 vertices, k=3
        {
            'verts': [(-8,-8), (0,-1), (8,-8), (1,0), (0,10), (-1,0)],
            'k': 3,
            'expected': 9.0
        },
        # Case 3: 16 vertices, k=2
        {
            'verts': [(0,0), (3,0), (3,3), (6,3), (8,0), (10,4), (10,10), (8,10), (8,6), (6,10), (6,11), (5,9), (4,7), (3,11), (2,1), (0,4)],
            'k': 2,
            'expected': 9.0
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, tc in enumerate(test_cases):
        n = len(tc['verts'])
        dut.num_vertices.value = n
        dut.k.value = tc['k']
        
        for i, (x, y) in enumerate(tc['verts']):
            dut.poly_x[i].value = to_fixed_q12_4(x)
            dut.poly_y[i].value = to_fixed_q12_4(y)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 500:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if dut.done.value:
            result_val = int(dut.result.value)
            result_float = from_fixed_q16_16(result_val)
            
            # Allow small tolerance for fixed-point approximations
            if abs(result_float - tc['expected']) < 0.1:
                print(f"Test {idx+1} PASSED: Got {result_float:.2f}, Expected {tc['expected']:.2f}")
                passed += 1
            else:
                print(f"Test {idx+1} FAILED: Got {result_float:.2f}, Expected {tc['expected']:.2f}")
        else:
            print(f"Test {idx+1} FAILED: Timeout")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
