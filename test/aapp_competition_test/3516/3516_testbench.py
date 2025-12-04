import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_game_optimizer(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1 (Sample Input 1): Expected output 91
    test1 = {
        'x0': 1, 's0': 1, 'a00':40, 'a01':30, 'a02':20, 'a03':10,
        'x1': 3, 's1': 1, 'a10':95, 'a11':95, 'a12':95, 'a13':10,
        'x2': 2, 's2': 1, 'a20':95, 'a21':50, 'a22':30, 'a23':20
    }

    # Test case 2: All levels use shortcut (1+1+1=3)
    test2 = {
        'x0':0, 's0':1, 'a00':5, 'a01':4, 'a02':3, 'a03':2,
        'x1':1, 's1':1, 'a10':5, 'a11':4, 'a12':3, 'a13':2,
        'x2':2, 's2':1, 'a20':5, 'a21':4, 'a22':3, 'a23':2
    }

    # Test case 3: Only one valid path
    test3 = {
        'x0':3, 's0':100, 'a00':200, 'a01':190, 'a02':180, 'a03':170,
        'x1':3, 's1':100, 'a10':200, 'a11':190, 'a12':180, 'a13':170,
        'x2':3, 's2':100, 'a20':200, 'a21':190, 'a22':180, 'a23':170
    }

    tests = [
        (test1, 91),
        (test2, 3),
        (test3, 300)  # 100 for each level since shortcuts require item 3
    ]

    passed = 0
    for test_data, expected in tests:
        # Set inputs
        for sig, val in test_data.items():
            getattr(dut, sig).value = val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Wait for done signal
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        total_time = dut.min_time.value
        if int(total_time) == expected:
            passed += 1
            dut._log.info(f"Success: got {total_time}, expected {expected}")
        else:
            dut._log.error(f"FAILED: got {total_time}, expected {expected}")
        
        await RisingEdge(dut.clk)  # Wait one more cycle between tests
    
    dut._log.info(f"{passed}/{len(tests)} tests passed")
