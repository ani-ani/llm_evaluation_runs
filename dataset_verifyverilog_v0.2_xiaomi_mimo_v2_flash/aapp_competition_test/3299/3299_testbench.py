import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

# Helper to convert inputs
# Input grid is 2x2. The module expects 4 inputs.
# We map the input string to these 4 values.

def run_test(dut, inputs, expected):
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_00.value = 0
    dut.grid_01.value = 0
    dut.grid_10.value = 0
    dut.grid_11.value = 0
    yield Timer(10, units='ns')
    dut.rst_n.value = 1
    yield Timer(10, units='ns')
    
    # Parse inputs (list of 4 ints)
    dut.grid_00.value = inputs[0]
    dut.grid_01.value = inputs[1]
    dut.grid_10.value = inputs[2]
    dut.grid_11.value = inputs[3]
    
    # Start
    dut.start.value = 1
    yield RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    # The loop is 3375 cycles max. For testing, we might want to simulate or reduce iteration count in code?
    # The prompt says "processes one candidate set per cycle". 3375 cycles is long for simulation but okay for benchmark.
    # We will wait for done or timeout.
    
    cycles = 0
    while not dut.done.value and cycles < 4000:
        yield RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 4000:
        raise TestFailure(f"Test timed out. Result: {int(dut.result.value)}")
        
    # Check result
    if int(dut.result.value) != expected:
        raise TestFailure(f"Expected {expected}, got {int(dut.result.value)}")
    
    print(f"Test passed: Inputs {inputs}, Result {int(dut.result.value)}")

@cocotb.test()
def test_magic_checkerboard(dut):
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    yield Timer(100, units="ns")
    
    # Test Case 1: From example (scaled to 2x2) 
    # 4x4 example:
    # 1 2 3 0
    # 0 0 5 6
    # 0 0 7 8
    # 7 0 0 10
    # Let's create a 2x2 subset for the test.
    # We'll use a simple 2x2 case.
    # Case 1: [1, 2, 0, 0] -> Min sum: Row0: 1<2. Col0: 1<val. Col1: 2<val. Diag: 1(odd) and val must be even.
    # Try v10=3 (min for col), v01=3 (min for row), v11=4 (min for col, row, even).
    # Sum = 1+2+3+4 = 10.
    # But wait, diag constraint: (0,0) is 1 (odd), (1,1) must be even. 4 is even. OK.
    # Row 1: 3 < 4. OK.
    # Is 10 the minimum? 
    # Let's try 1, 2, 3, 4 -> 10.
    # What if 1, 2, 3, 6? -> 12. Worse.
    # Case 1: [1, 2, 0, 0] -> Output should be 10.
    dut._log.info("Running Test Case 1")
    yield run_test(dut, [1, 2, 0, 0], 10)

    # Case 2: [0, 0, 0, 0] -> All empty.
    # We need smallest positive integers.
    # Try 1, 2, 3, 4. 
    # 1 < 2, 1 < 3, 2 < 4, 3 < 4. 
    # 1(odd) and 4(even) -> Different parity. OK.
    # Sum = 10.
    dut._log.info("Running Test Case 2")
    yield run_test(dut, [0, 0, 0, 0], 10)

    # Case 3: [1, 0, 0, 2] 
    # 1 and 2 on diagonal. 1 is odd, 2 is even. Parity OK.
    # Constraints: 1 < v01, 1 < v10, v10 < 2, v01 < 2.
    # Since v10 < 2 and v10 > 1, no integer solution. Should be -1 (255).
    dut._log.info("Running Test Case 3")
    yield run_test(dut, [1, 0, 0, 2], 255)
    
    # Case 4: [0, 3, 4, 0]
    # Row 0: 0 < 3. Col 1: 3 < 0 (invalid input, wait. Input is fixed.
    # Input is fixed. If input has 3 and 4 fixed.
    # Grid: [0, 3, 4, 0]
    # c00 < c01 (v00 < 3)
    # c10 < c11 (4 < v11)
    # c00 < c10 (v00 < 4)
    # c01 < c11 (3 < v11)
    # Diag: v00[0] ^ v11[0] == 1
    # v00 can be 1 or 2.
    # v11 must be > 3. Min 4. 
    # If v00=1, v11 must be even (opposite of 1). Min even > 3 is 4. Sum = 1+3+4+4 = 12.
    # If v00=2, v11 must be odd (opposite of 2). Min odd > 3 is 5. Sum = 2+3+4+5 = 14.
    # Min sum is 12.
    dut._log.info("Running Test Case 4")
    yield run_test(dut, [0, 3, 4, 0], 12)

    # Case 5: [2, 0, 0, 3] -> Diag 2(even), 3(odd). Parity OK.
    # v01 > 2, v10 > 2, v10 < 3, v01 < 3. No integer v10 or v01 exists. -1.
    dut._log.info("Running Test Case 5")
    yield run_test(dut, [2, 0, 0, 3], 255)