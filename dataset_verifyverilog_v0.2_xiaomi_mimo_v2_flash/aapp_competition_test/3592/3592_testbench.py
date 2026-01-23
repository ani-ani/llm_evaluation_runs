import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_profit_calculator(dut):
    """Test profit calculator module"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.total_profit.value = 0
    dut.profit_pita.value = 0
    dut.profit_pizza.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: 725.85 total, 1.71 pita, 2.38 pizza
    # Scaled: 72585, 171, 238
    # Expected: 199 pitas, 162 pizzas
    dut.total_profit.value = 72585
    dut.profit_pita.value = 171
    dut.profit_pizza.value = 238
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    found_solutions = []
    timeout = 0
    
    while timeout < 500:
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            pitas = int(dut.num_pitas.value)
            pizzas = int(dut.num_pizzas.value)
            found_solutions.append((pitas, pizzas))
        if dut.done.value == 1:
            break
        timeout += 1
    
    # Check results for test case 1
    # We expect exactly one solution: (199, 162)
    if (199, 162) not in found_solutions:
        raise TestFailure(f"Test Case 1 Failed. Expected (199, 162). Found: {found_solutions}")
    
    print(f"Test Case 1 passed. Solutions: {found_solutions}")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: 100.00 total, 20.00 pita, 10.00 pizza
    # Scaled: 10000, 2000, 1000
    # Expected: (0,10), (1,8), (2,6), (3,4), (4,2), (5,0)
    dut.total_profit.value = 10000
    dut.profit_pita.value = 2000
    dut.profit_pizza.value = 1000
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    found_solutions = []
    timeout = 0
    
    while timeout < 500:
        await RisingEdge(dut.clk)
        if dut.valid.value == 1:
            pitas = int(dut.num_pitas.value)
            pizzas = int(dut.num_pizzas.value)
            found_solutions.append((pitas, pizzas))
        if dut.done.value == 1:
            break
        timeout += 1

    expected_solutions = [(0, 10), (1, 8), (2, 6), (3, 4), (4, 2), (5, 0)]
    if found_solutions != expected_solutions:
        raise TestFailure(f"Test Case 2 Failed. Expected {expected_solutions}. Found: {found_solutions}")
    
    print(f"Test Case 2 passed. Solutions: {found_solutions}")
    print("All tests passed!")
