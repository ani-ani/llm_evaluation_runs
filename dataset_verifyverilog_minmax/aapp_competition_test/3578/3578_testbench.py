import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_airline_cost(dut):
    # Create 10MHz clock
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled inputs)
    test_cases = [
        (
            # Input 1: Sample Input from problem
            5, 3, 2, 
            [from_tuple((1,2,1000)), from_tuple((2,3,1000)), from_tuple((4,5,500)), 0, 0, 0],
            [from_tuple((1,4,300)), from_tuple((3,5,300)), 0, 0, 0, 0],
            3100
        ),
        (
            # Input 2: Extended Sample
            6, 5, 2, 
            [from_tuple((1,2,1000)), from_tuple((2,3,1000)), from_tuple((1,3,1000)), from_tuple((2,4,1000)), from_tuple((5,6,500)), 0],
            [from_tuple((2,5,300)), from_tuple((4,6,300)), 0, 0, 0, 0],
            5100
        )
    ]
    
    # Helper function to pack flight data
    def from_tuple(t):
        (a,b,c) = t
        return (a << 18) | (b << 14) | c
    
    passed = 0
    total = len(test_cases)
    
    for i, (n_val, r_val, f_val, req_data, add_data, expected) in enumerate(test_cases):
        # Reset device
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.N.value = n_val
        dut.R.value = r_val
        dut.F.value = f_val
        for j in range(6):
            dut.req_flights[j].value = int(req_data[j])
            dut.add_flights[j].value = int(add_data[j])
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 50 cycles)
        timeout = 50
        while not dut.done.value:
            await RisingEdge(dut.clk)
            timeout -= 1
            if timeout == 0:
                break
        
        # Check result
        if timeout > 0 and dut.minimal_cost.value == expected:
            passed += 1
            dut._log.info(f"Test {i+1} passed: {dut.minimal_cost.value} == {expected}")
        else:
            if timeout == 0:
                dut._log.error(f"Test {i+1} failed: Timeout waiting for done")
            else:
                dut._log.error(f"Test {i+1} failed: Got {dut.minimal_cost.value}, expected {expected}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total