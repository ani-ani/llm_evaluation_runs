import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def encode_load_data(firm_idx, state_idx, is_supplier, is_factory):
    """Helper to encode data for loading transport firm states"""
    return (firm_idx << 8) | (state_idx << 4) | (is_supplier << 3) | (is_factory << 2)

@cocotb.test()
async def test_max_matching_basic(dut):
    """Test basic case: 3 suppliers, 3 factories, 3 transport firms -> max 2"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_en.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load supplier states: A=0, B=1, C=2
    dut.load_en.value = 1
    dut.load_idx.value = 0  # Supplier 0
    dut.load_data.value = 0  # State 0 (A)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 1  # Supplier 1
    dut.load_data.value = 1  # State 1 (B)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 2  # Supplier 2
    dut.load_data.value = 2  # State 2 (C)
    await RisingEdge(dut.clk)
    
    # Load factory states: D=3, E=4, F=5
    dut.load_idx.value = 4  # Factory 0
    dut.load_data.value = 3  # State 3 (D)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 5  # Factory 1
    dut.load_data.value = 4  # State 4 (E)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 6  # Factory 2
    dut.load_data.value = 5  # State 5 (F)
    await RisingEdge(dut.clk)
    
    # Load transport firm 0: states A(0), E(4), G(6)
    dut.load_idx.value = 8  # Firm 0, count
    dut.load_data.value = (0 << 8) | 3  # firm 0, 3 states
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 12  # First state for firm 0
    dut.load_data.value = encode_load_data(0, 0, 1, 0)  # state A, supplier
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 13
    dut.load_data.value = encode_load_data(0, 4, 0, 1)  # state E, factory
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 14
    dut.load_data.value = encode_load_data(0, 6, 0, 0)  # state G, neither
    await RisingEdge(dut.clk)
    
    # Load transport firm 1: states A(0), C(2), E(4)
    dut.load_idx.value = 9  # Firm 1, count
    dut.load_data.value = (1 << 8) | 3  # firm 1, 3 states
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 15
    dut.load_data.value = encode_load_data(1, 0, 1, 0)  # state A, supplier
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 16
    dut.load_data.value = encode_load_data(1, 2, 1, 0)  # state C, supplier
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 17
    dut.load_data.value = encode_load_data(1, 4, 0, 1)  # state E, factory
    await RisingEdge(dut.clk)
    
    # Load transport firm 2: states B(1), D(3), F(5)
    dut.load_idx.value = 10  # Firm 2, count
    dut.load_data.value = (2 << 8) | 3  # firm 2, 3 states
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 18
    dut.load_data.value = encode_load_data(2, 1, 1, 0)  # state B, supplier
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 19
    dut.load_data.value = encode_load_data(2, 3, 0, 1)  # state D, factory
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 20
    dut.load_data.value = encode_load_data(2, 5, 0, 1)  # state F, factory
    await RisingEdge(dut.clk)
    
    # Finish loading
    dut.load_en.value = 0
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 64 cycles)
    for _ in range(64):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    # Check result
    if not dut.done.value:
        raise TestFailure("Computation did not complete within 64 cycles")
    
    if not dut.valid.value:
        raise TestFailure("Output not marked valid")
    
    result = int(dut.max_match.value)
    dut._log.info(f"Maximum matching: {result}")
    
    if result != 2:
        raise TestFailure(f"Expected max_match = 2, got {result}")

@cocotb.test()
async def test_max_matching_complete(dut):
    """Test complete matching case: 3 suppliers, 3 factories, 4 transport firms -> max 3"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_en.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load same suppliers/factories as before
    dut.load_en.value = 1
    dut.load_idx.value = 0
    dut.load_data.value = 0
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 1
    dut.load_data.value = 1
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 2
    dut.load_data.value = 2
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 4
    dut.load_data.value = 3
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 5
    dut.load_data.value = 4
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 6
    dut.load_data.value = 5
    await RisingEdge(dut.clk)
    
    # Firm 0: A(0), E(4), G(6)
    dut.load_idx.value = 8
    dut.load_data.value = (0 << 8) | 3
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 12
    dut.load_data.value = encode_load_data(0, 0, 1, 0)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 13
    dut.load_data.value = encode_load_data(0, 4, 0, 1)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 14
    dut.load_data.value = encode_load_data(0, 6, 0, 0)
    await RisingEdge(dut.clk)
    
    # Firm 1: A(0), C(2), E(4)
    dut.load_idx.value = 9
    dut.load_data.value = (1 << 8) | 3
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 15
    dut.load_data.value = encode_load_data(1, 0, 1, 0)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 16
    dut.load_data.value = encode_load_data(1, 2, 1, 0)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 17
    dut.load_data.value = encode_load_data(1, 4, 0, 1)
    await RisingEdge(dut.clk)
    
    # Firm 2: B(1), D(3), F(5)
    dut.load_idx.value = 10
    dut.load_data.value = (2 << 8) | 3
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 18
    dut.load_data.value = encode_load_data(2, 1, 1, 0)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 19
    dut.load_data.value = encode_load_data(2, 3, 0, 1)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 20
    dut.load_data.value = encode_load_data(2, 5, 0, 1)
    await RisingEdge(dut.clk)
    
    # Firm 3: G(6), F(5) - NEW FIRM
    dut.load_idx.value = 11
    dut.load_data.value = (3 << 8) | 2
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 21
    dut.load_data.value = encode_load_data(3, 6, 0, 0)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 22
    dut.load_data.value = encode_load_data(3, 5, 0, 1)
    await RisingEdge(dut.clk)
    
    # Finish loading
    dut.load_en.value = 0
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(64):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Computation did not complete within 64 cycles")
    
    if not dut.valid.value:
        raise TestFailure("Output not marked valid")
    
    result = int(dut.max_match.value)
    dut._log.info(f"Maximum matching: {result}")
    
    if result != 3:
        raise TestFailure(f"Expected max_match = 3, got {result}")

@cocotb.test()
async def test_max_matching_simple(dut):
    """Test simple 1-to-1 matching: 1 supplier, 1 factory, direct connection"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_en.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load: 1 supplier (state 0), 1 factory (state 1), 1 firm (connects 0 and 1)
    dut.load_en.value = 1
    
    # Supplier 0 at state 0
    dut.load_idx.value = 0
    dut.load_data.value = 0
    await RisingEdge(dut.clk)
    
    # Factory 0 at state 1
    dut.load_idx.value = 4
    dut.load_data.value = 1
    await RisingEdge(dut.clk)
    
    # Firm 0: states 0 and 1
    dut.load_idx.value = 8
    dut.load_data.value = (0 << 8) | 2
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 12
    dut.load_data.value = encode_load_data(0, 0, 1, 0)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 13
    dut.load_data.value = encode_load_data(0, 1, 0, 1)
    await RisingEdge(dut.clk)
    
    dut.load_en.value = 0
    await RisingEdge(dut.clk)
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    for _ in range(64):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.max_match.value)
    if result != 1:
        raise TestFailure(f"Expected 1, got {result}")
    dut._log.info(f"Simple test passed: {result}")

@cocotb.test()
async def test_max_matching_no_connection(dut):
    """Test no matching possible"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_en.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load: supplier at 0, factory at 1, but firm connects 0 and 2 (no factory)
    dut.load_en.value = 1
    
    dut.load_idx.value = 0
    dut.load_data.value = 0
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 4
    dut.load_data.value = 1
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 8
    dut.load_data.value = (0 << 8) | 2
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 12
    dut.load_data.value = encode_load_data(0, 0, 1, 0)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 13
    dut.load_data.value = encode_load_data(0, 2, 0, 0)  # Not a factory
    await RisingEdge(dut.clk)
    
    dut.load_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(64):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.max_match.value)
    if result != 0:
        raise TestFailure(f"Expected 0, got {result}")
    dut._log.info(f"No connection test passed: {result}")

@cocotb.test()
async def test_max_matching_multiple_routes(dut):
    """Test multiple possible matchings to same factory"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_en.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 2 suppliers (0,1), 1 factory (2), 2 firms (0 connects 0->2, 1 connects 1->2)
    dut.load_en.value = 1
    
    dut.load_idx.value = 0
    dut.load_data.value = 0
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 1
    dut.load_data.value = 1
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 4
    dut.load_data.value = 2
    await RisingEdge(dut.clk)
    
    # Firm 0
    dut.load_idx.value = 8
    dut.load_data.value = (0 << 8) | 2
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 12
    dut.load_data.value = encode_load_data(0, 0, 1, 0)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 13
    dut.load_data.value = encode_load_data(0, 2, 0, 1)
    await RisingEdge(dut.clk)
    
    # Firm 1
    dut.load_idx.value = 9
    dut.load_data.value = (1 << 8) | 2
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 14
    dut.load_data.value = encode_load_data(1, 1, 1, 0)
    await RisingEdge(dut.clk)
    
    dut.load_idx.value = 15
    dut.load_data.value = encode_load_data(1, 2, 0, 1)
    await RisingEdge(dut.clk)
    
    dut.load_en.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(64):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result = int(dut.max_match.value)
    # Should match 1 factory (max of 1 factory can be matched even with 2 suppliers)
    if result != 1:
        raise TestFailure(f"Expected 1, got {result}")
    dut._log.info(f"Multiple routes test passed: {result}")

print("All tests defined. Running with: pytest -xvs")