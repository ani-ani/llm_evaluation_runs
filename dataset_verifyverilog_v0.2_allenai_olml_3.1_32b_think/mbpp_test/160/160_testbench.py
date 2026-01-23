import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_diophantine_solver(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    async def run_test(a, b, n, expected_x, expected_y, expected_valid):
        dut.a.value = a
        dut.b.value = b
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 20 cycles to be safe)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if dut.done.value != 1:
            raise TestFailure(f"Test failed for inputs a={a}, b={b}, n={n}: Done signal not asserted")
        
        if dut.valid.value != expected_valid:
            raise TestFailure(f"Test failed for inputs a={a}, b={b}, n={n}: Expected valid={expected_valid}, got {dut.valid.value}")
        
        if expected_valid:
            if dut.x.value != expected_x or dut.y.value != expected_y:
                raise TestFailure(f"Test failed for inputs a={a}, b={b}, n={n}: Expected ({expected_x}, {expected_y}), got ({dut.x.value}, {dut.y.value})")

    # Test 1: find_solution(2, 3, 7) == (2, 1)
    print("Running Test 1: a=2, b=3, n=7")
    await run_test(2, 3, 7, 2, 1, 1)

    # Test 2: find_solution(4, 2, 7) == None
    print("Running Test 2: a=4, b=2, n=7")
    await run_test(4, 2, 7, 0, 0, 0)

    # Test 3: find_solution(1, 13, 17) == (4, 1)
    print("Running Test 3: a=1, b=13, n=17")
    await run_test(1, 13, 17, 4, 1, 1)
    
    print("All 3/3 tests passed")