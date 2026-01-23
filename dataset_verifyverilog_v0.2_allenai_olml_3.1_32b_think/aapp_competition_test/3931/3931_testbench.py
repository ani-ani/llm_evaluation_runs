import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_travel_expense_calculator(dut):
    """Test the travel expense calculator logic"""
    
    # Create a clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.trip_valid.value = 0
    dut.trip_done.value = 0
    dut.num_trips.value = 0
    dut.max_cards.value = 0
    dut.reg_cost.value = 0
    dut.trans_cost.value = 0
    dut.card_cost.value = 0
    dut.trip_start_char.value = 0
    dut.trip_end_char.value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: From Example 1
    # Input: 3 5 3 1 8
    # Trips: BerBank University (5), University BerMall (3), University BerBank (5)
    # Total: 13. Card on route BerBank-University saves (5+5) - 8 = 2? Wait.
    # Trip 1: B->U (cost 5). Route B-U cost 5.
    # Trip 2: U->M (cost 3, trans). Route U-M cost 3.
    # Trip 3: U->B (cost 5, trans). Route B-U cost adds 5. Total B-U cost = 10.
    # Optimization: Card on B-U (cost 8) replaces 10. Total = 8 (card) + 3 (trip 2) = 11.
    
    n = 3
    a = 5
    b = 3
    k = 1
    f = 8
    
    dut.num_trips.value = n
    dut.max_cards.value = k
    dut.reg_cost.value = a
    dut.trans_cost.value = b
    dut.card_cost.value = f
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for ready
    while not dut.trip_ready.value:
        await RisingEdge(dut.clk)
        
    # Trip 1: 'B' -> 'U'
    # ASCII: B=66, U=85
    dut.trip_start_char.value = 66
    dut.trip_end_char.value = 85
    dut.trip_valid.value = 1
    await RisingEdge(dut.clk)
    dut.trip_valid.value = 0
    while not dut.trip_ready.value:
        await RisingEdge(dut.clk)
        
    # Trip 2: 'U' -> 'M' (transshipment)
    # ASCII: M=77
    dut.trip_start_char.value = 85
    dut.trip_end_char.value = 77
    dut.trip_valid.value = 1
    await RisingEdge(dut.clk)
    dut.trip_valid.value = 0
    while not dut.trip_ready.value:
        await RisingEdge(dut.clk)
        
    # Trip 3: 'U' -> 'B' (transshipment)
    dut.trip_start_char.value = 85
    dut.trip_end_char.value = 66
    dut.trip_valid.value = 1
    await RisingEdge(dut.clk)
    dut.trip_valid.value = 0
    
    # Signal done
    dut.trip_done.value = 1
    await RisingEdge(dut.clk)
    dut.trip_done.value = 0
    
    # Wait for done
    timeout = 100
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
    if timeout == 0:
        raise TestFailure("Timeout waiting for done signal")
        
    result = int(dut.result.value)
    dut._log.info(f"Test 1 Result: {result}")
    if result != 11:
        raise TestFailure(f"Expected 11, got {result}")
        
    # Test Case 2: From Example 2
    # Input: 4 2 1 300 1000
    # Trips: a A, A aa, aa AA, AA a
    # All transshipments except first. Total = 2 + 1 + 1 + 1 = 5.
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    n = 4
    a = 2
    b = 1
    k = 300
    f = 1000
    
    dut.num_trips.value = n
    dut.max_cards.value = k
    dut.reg_cost.value = a
    dut.trans_cost.value = b
    dut.card_cost.value = f
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.trip_ready.value:
        await RisingEdge(dut.clk)
        
    # Trip 1: 'a' -> 'A' (97->65)
    dut.trip_start_char.value = 97
    dut.trip_end_char.value = 65
    dut.trip_valid.value = 1
    await RisingEdge(dut.clk)
    dut.trip_valid.value = 0
    while not dut.trip_ready.value:
        await RisingEdge(dut.clk)
        
    # Trip 2: 'A' -> 'a' (65->97) -> Trans
    dut.trip_start_char.value = 65
    dut.trip_end_char.value = 97
    dut.trip_valid.value = 1
    await RisingEdge(dut.clk)
    dut.trip_valid.value = 0
    while not dut.trip_ready.value:
        await RisingEdge(dut.clk)
        
    # Trip 3: 'a' -> 'a' (97->97) -> Wait, Input says: aa -> AA. 
    # Let's assume aa = 'a' (97), AA = 'A' (65). Wait, input: "aa AA"
    # 'a' is 97. 'A' is 65. So 'a' -> 'A'. Trans.
    dut.trip_start_char.value = 97
    dut.trip_end_char.value = 65
    dut.trip_valid.value = 1
    await RisingEdge(dut.clk)
    dut.trip_valid.value = 0
    while not dut.trip_ready.value:
        await RisingEdge(dut.clk)
        
    # Trip 4: 'AA' -> 'a' (65->97) -> Trans
    dut.trip_start_char.value = 65
    dut.trip_end_char.value = 97
    dut.trip_valid.value = 1
    await RisingEdge(dut.clk)
    dut.trip_valid.value = 0
    
    dut.trip_done.value = 1
    await RisingEdge(dut.clk)
    dut.trip_done.value = 0
    
    timeout = 100
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
        
    if timeout == 0:
        raise TestFailure("Timeout waiting for done signal")
        
    result = int(dut.result.value)
    dut._log.info(f"Test 2 Result: {result}")
    if result != 5:
        raise TestFailure(f"Expected 5, got {result}")
        
    # Test Case 3: Optimized Card Case
    # 2 trips, a=10, b=1, k=1, f=5
    # Trips: X->Y (cost 10), Y->X (cost 1). 
    # Total raw = 11.
    # Route X-Y cost = 11. Card cost = 5. New total = 5 + 0 = 5.
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    n = 2
    a = 10
    b = 1
    k = 1
    f = 5
    
    dut.num_trips.value = n
    dut.max_cards.value = k
    dut.reg_cost.value = a
    dut.trans_cost.value = b
    dut.card_cost.value = f
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.trip_ready.value:
        await RisingEdge(dut.clk)
    
    # Trip 1: 'X'(88) -> 'Y'(89)
    dut.trip_start_char.value = 88
    dut.trip_end_char.value = 89
    dut.trip_valid.value = 1
    await RisingEdge(dut.clk)
    dut.trip_valid.value = 0
    while not dut.trip_ready.value:
        await RisingEdge(dut.clk)
    
    # Trip 2: 'Y'(89) -> 'X'(88) -> Trans
    dut.trip_start_char.value = 89
    dut.trip_end_char.value = 88
    dut.trip_valid.value = 1
    await RisingEdge(dut.clk)
    dut.trip_valid.value = 0
    
    dut.trip_done.value = 1
    await RisingEdge(dut.clk)
    dut.trip_done.value = 0
    
    timeout = 100
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
    
    if timeout == 0:
        raise TestFailure("Timeout")
        
    result = int(dut.result.value)
    dut._log.info(f"Test 3 Result: {result}")
    if result != 5:
        raise TestFailure(f"Expected 5, got {result}")
        
    dut._log.info("All tests passed!")
