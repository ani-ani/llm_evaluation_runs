import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def num_to_bin(num):
    return num & 0x7F  # 7-bit value

def card_row_to_val(row):
    # Pack 8 numbers into a single value (not used directly in this testbench)
    pass

@cocotb.test()
async def test_bingo_tie_basic(dut):
    """Test basic tie detection between two cards"""
    # Card 1 row 2: {11, 25, 40, 49, 61}
    # Card 2 row 4: {10, 25, 31, 57, 64}
    # They share 25, so a tie is possible
    
    dut.card1_row0.value = num_to_bin(3) | (num_to_bin(29) << 7) | (num_to_bin(45) << 14) | (num_to_bin(56) << 21)
    dut.card1_row1.value = num_to_bin(1) | (num_to_bin(19) << 7) | (num_to_bin(43) << 14) | (num_to_bin(50) << 21)
    dut.card1_row2.value = num_to_bin(11) | (num_to_bin(25) << 7) | (num_to_bin(40) << 14) | (num_to_bin(49) << 21)
    dut.card1_row3.value = num_to_bin(9) | (num_to_bin(23) << 7) | (num_to_bin(31) << 14) | (num_to_bin(58) << 21)
    dut.card1_row4.value = num_to_bin(4) | (num_to_bin(27) << 7) | (num_to_bin(42) << 14) | (num_to_bin(54) << 21)
    dut.card1_row5.value = num_to_bin(68)  # Remaining numbers
    dut.card1_row6.value = 0
    dut.card1_row7.value = 0
    
    # Note: This testbench assumes the module has been redesigned to accept
    # simple row inputs (8 rows with 5 numbers each, but represented as 32-bit values)
    # For actual implementation, a different interface might be needed.
    
    await Timer(10, units='ns')
    
    # Check if tie is detected (this depends on module implementation)
    # dut._log.info(f"Tie possible: {dut.tie_possible.value}")

# Additional test cases would need the specific module interface
# This testbench is illustrative and requires a concrete module definition
# to be fully functional.

@cocotb.test()
async def test_no_tie(dut):
    """Test no tie scenario"""
    # Set up two cards with no common numbers in any rows
    # Expect tie_possible = 0
    for i in range(8):
        setattr(dut, f'card1_row{i}', num_to_bin(i*5+1))
        setattr(dut, f'card2_row{i}', num_to_bin(i*5+100))
    
    await Timer(10, units='ns')
    # dut._log.info(f"Tie possible: {dut.tie_possible.value}")

@cocotb.test()
async def test_tie_on_last_row(dut):
    """Test tie detection with specific rows"""
    # Manually set values for testing
    dut.card1_row0.value = 0
    dut.card1_row1.value = 0
    dut.card1_row2.value = 0
    dut.card1_row3.value = 0
    dut.card1_row4.value = 0
    dut.card1_row5.value = 0
    dut.card1_row6.value = 0
    dut.card1_row7.value = 0
    
    dut.card2_row0.value = 0
    dut.card2_row1.value = 0
    dut.card2_row2.value = 0
    dut.card2_row3.value = 0
    dut.card2_row4.value = 0
    dut.card2_row5.value = 0
    dut.card2_row6.value = 0
    dut.card2_row7.value = 0
    
    await Timer(10, units='ns')
    # Verification logic
