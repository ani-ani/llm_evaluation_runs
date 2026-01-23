import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper to convert float to Q16.16 fixed point integer
def to_q1616(value):
    return int(value * 65536)

@cocotb.test()
async def test_loss_amount_basic(dut):
    """Test basic loss calculation: sale > actual"""
    # Test case: actual=100, sale=200, expected loss=100
    dut.actual_cost.value = to_q1616(100)
    dut.sale_amount.value = to_q1616(200)
    
    await Timer(10, units='ns')
    
    expected_loss = to_q1616(100)
    if dut.loss.value.integer != expected_loss:
        raise TestFailure(f"Loss mismatch: got {dut.loss.value.integer}, expected {expected_loss}")
    print(f"Test 1 Passed: Loss calculated correctly")

@cocotb.test()
async def test_loss_amount_zero(dut):
    """Test no loss case: actual >= sale"""
    # Test case: actual=1500, sale=1200, expected loss=0
    dut.actual_cost.value = to_q1616(1500)
    dut.sale_amount.value = to_q1616(1200)
    
    await Timer(10, units='ns')
    
    if dut.loss.value.integer != 0:
        raise TestFailure(f"Loss mismatch: got {dut.loss.value.integer}, expected 0")
    print(f"Test 2 Passed: No loss calculated correctly")

@cocotb.test()
async def test_loss_amount_large(dut):
    """Test large loss calculation"""
    # Test case: actual=2000, sale=5000, expected loss=3000
    dut.actual_cost.value = to_q1616(2000)
    dut.sale_amount.value = to_q1616(5000)
    
    await Timer(10, units='ns')
    
    expected_loss = to_q1616(3000)
    if dut.loss.value.integer != expected_loss:
        raise TestFailure(f"Loss mismatch: got {dut.loss.value.integer}, expected {expected_loss}")
    print(f"Test 3 Passed: Large loss calculated correctly")

@cocotb.test()
async def test_loss_amount_equal(dut):
    """Test equal amounts case"""
    # Test case: actual=1000, sale=1000, expected loss=0
    dut.actual_cost.value = to_q1616(1000)
    dut.sale_amount.value = to_q1616(1000)
    
    await Timer(10, units='ns')
    
    if dut.loss.value.integer != 0:
        raise TestFailure(f"Loss mismatch: got {dut.loss.value.integer}, expected 0")
    print(f"Test 4 Passed: Equal amounts handled correctly")