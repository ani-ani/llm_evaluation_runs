import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_optimizer(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled for Q16.16 fixed-point)
    cases = [
        { 
            'planets': [[0,0,1], [0,1,1], [2,0,3], [2,1,3]],
            'expected': 2.0 * 65536 # 2.0 in Q16.16
        },
        {
            'planets': [[0,0,0], [50,0,0], [0,50,0], [50,50,0]],
            'expected': 100.0 * 65536 # sqrt(50^2+50^2)*2 in Q
        }
    ]
    
    passed = 0
    for i, test in enumerate(cases):
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load planet coordinates
        (dut.x1.value, dut.y1.value, dut.z1.value) = test['planets'][0]
        (dut.x2.value, dut.y2.value, dut.z2.value) = test['planets'][1]
        (dut.x3.value, dut.y3.value, dut.z3.value) = test['planets'][2]
        (dut.x4.value, dut.y4.value, dut.z4.value) = test['planets'][3]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        for _ in range(55):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Verify result
        tol = 0.1 * 65536 # 0.1 tolerance in Q16.16
        assert abs(int(dut.min_distance.value) - test['expected']) <= tol, 
            f"Case {i} failed: Got {dut.min_distance.value/65536:.2f}, Expected {test['expected']/65536}"
        passed += 1
    
    dut._log.info(f"{passed}/{len(cases)} tests passed")