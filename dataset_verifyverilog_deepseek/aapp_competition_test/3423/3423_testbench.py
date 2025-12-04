import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
import random

@cocotb.test()
async def test_package_solver(dut):
    # Define test cases (packages=4, dependency matrices)
    test_cases = [
        (4, [
            [0,0,0,0],   # Package 0 no deps
            [1,0,0,0],   # Package 1 depends on 0
            [1,0,0,0],   # Package 2 depends on 0
            [0,1,1,0]    # Package 3 depends on 1,2
        ], [0,1,2,3], [0,1,2,3], True),  # Valid order: [0,1,2,3] or [0,2,1,3] but pick lex smallest
        (4, [
            [0,1,0,0],   # Cyclic TODO: Complete testbench