import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_settle_bills_basic(dut):
    """Test basic settlement with simple debts"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.receipt_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 4 people, 2 receipts
    # Person 0 paid 1 for person 1
    # Person 2 paid 1 for person 3
    # Balances: [1, -1, 1, -1]
    # Expected: 2 transactions
    
    dut.num_people.value = 4
    dut.num_receipts.value = 2
    await RisingEdge(dut.clk)
    
    # Receipt 1
    dut.payer.value = 0
    dut.beneficiary.value = 1
    dut.amount.value = 1
    dut.receipt_valid.value = 1
    await RisingEdge(dut.clk)
    dut.receipt_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Receipt 2
    dut.payer.value = 2
    dut.beneficiary.value = 3
    dut.amount.value = 1
    dut.receipt_valid.value = 1
    await RisingEdge(dut.clk)
    dut.receipt_valid.value = 0
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Check result
    assert dut.num_transactions.value == 2, f"Expected 2 transactions, got {int(dut.num_transactions.value)}"
    print("Test 1 passed: 2 transactions")

@cocotb.test()
async def test_settle_bills_zero(dut):
    """Test case where no transactions needed"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.receipt_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: 5 people, 5 receipts forming a cycle
    # Each person paid 3 for next person
    # Balances all zero
    # Expected: 0 transactions
    
    dut.num_people.value = 5
    dut.num_receipts.value = 5
    await RisingEdge(dut.clk)
    
    receipts = [(0,1,3), (1,2,3), (2,3,3), (3,4,3), (4,0,3)]
    for payer, beneficiary, amount in receipts:
        dut.payer.value = payer
        dut.beneficiary.value = beneficiary
        dut.amount.value = amount
        dut.receipt_valid.value = 1
        await RisingEdge(dut.clk)
        dut.receipt_valid.value = 0
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.num_transactions.value == 0, f"Expected 0 transactions, got {int(dut.num_transactions.value)}"
    print("Test 2 passed: 0 transactions")

@cocotb.test()
async def test_settle_bills_all_from_one(dut):
    """Test case where one person paid for everyone"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.receipt_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: 5 people, 4 receipts
    # Person 0 paid 1 for each of 1,2,3,4
    # Balances: [4, -1, -1, -1, -1]
    # Expected: 4 transactions
    
    dut.num_people.value = 5
    dut.num_receipts.value = 4
    await RisingEdge(dut.clk)
    
    for i in range(1, 5):
        dut.payer.value = 0
        dut.beneficiary.value = i
        dut.amount.value = 1
        dut.receipt_valid.value = 1
        await RisingEdge(dut.clk)
        dut.receipt_valid.value = 0
        await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.num_transactions.value == 4, f"Expected 4 transactions, got {int(dut.num_transactions.value)}"
    print("Test 3 passed: 4 transactions")

@cocotb.test()
async def test_settle_bills_three_people(dut):
    """Test with 3 people in chain"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.receipt_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 3 people, 2 receipts
    # Person 0 paid 10 for person 1
    # Person 1 paid 5 for person 2
    # Balances: [10, -5, -5]
    # Expected: 2 transactions (0->1:5, 0->2:5)
    
    dut.num_people.value = 3
    dut.num_receipts.value = 2
    await RisingEdge(dut.clk)
    
    dut.payer.value = 0
    dut.beneficiary.value = 1
    dut.amount.value = 10
    dut.receipt_valid.value = 1
    await RisingEdge(dut.clk)
    dut.receipt_valid.value = 0
    await RisingEdge(dut.clk)
    
    dut.payer.value = 1
    dut.beneficiary.value = 2
    dut.amount.value = 5
    dut.receipt_valid.value = 1
    await RisingEdge(dut.clk)
    dut.receipt_valid.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.num_transactions.value == 2, f"Expected 2 transactions, got {int(dut.num_transactions.value)}"
    print("Test 4 passed: 2 transactions")

@cocotb.test()
async def test_settle_bills_no_receipts(dut):
    """Test with no receipts"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.receipt_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 5 people, 0 receipts
    # All balances zero
    # Expected: 0 transactions
    
    dut.num_people.value = 5
    dut.num_receipts.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.num_transactions.value == 0, f"Expected 0 transactions, got {int(dut.num_transactions.value)}"
    print("Test 5 passed: 0 transactions")
    
    # Print summary
    print("
=== Summary: 5/5 tests passed ===")