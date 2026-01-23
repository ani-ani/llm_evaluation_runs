import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

class QuerySystem:
    def __init__(self, dut):
        self.dut = dut
        self.log = dut._log

    async def reset(self):
        self.dut.rst_n.value = 0
        self.dut.start.value = 0
        self.dut.query_type.value = 0
        self.dut.K_in.value = 0
        self.dut.x_in.value = 0
        self.dut.d_in.value = 0
        for i in range(8):
            self.dut.p_in[i].value = 0
        await Timer(10, units='ns')
        self.dut.rst_n.value = 1
        await RisingEdge(self.dut.clk)

    async def wait_ready(self):
        while not self.dut.ready.value:
            await RisingEdge(self.dut.clk)

    async def send_query_0(self, k, x, p_list):
        # Type 0: 0 K x p1 p2 ... pK
        await self.wait_ready()
        self.dut.query_type.value = 0
        self.dut.K_in.value = k
        self.dut.x_in.value = x
        for i in range(8):
            if i < len(p_list):
                self.dut.p_in[i].value = p_list[i]
            else:
                self.dut.p_in[i].value = 0
        self.dut.start.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.start.value = 0
        # Wait for done (ready goes high again)
        await self.wait_ready()

    async def send_query_1(self, d, x):
        # Type 1: 1 d x
        await self.wait_ready()
        self.dut.query_type.value = 1
        self.dut.x_in.value = x
        self.dut.d_in.value = d
        self.dut.start.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.start.value = 0
        # Wait for result_valid
        while not self.dut.result_valid.value:
            await RisingEdge(self.dut.clk)
        return int(self.dut.result.value)

@cocotb.test()
async def test_teacher_rotation(dut):
    """Test teacher rotation logic"""
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    sys = QuerySystem(dut)
    await sys.reset()

    # Sample Input 1:
    # 3 4 5
    # 1 3 4   -> Query teacher 3 at week 4
    # 0 2 2 3 2 -> Rotate (3,2) at week 2
    # 1 3 2   -> Query teacher 3 at week 2
    # 1 2 4   -> Query teacher 2 at week 4
    # 1 1 4   -> Query teacher 1 at week 4
    
    # Sample Output: 3, 2, 3, 1
    # Note: Problem uses 1-based indexing. Convert to 0-based for logic.
    # Output expects 1-based.

    print("--- Test Case 1 ---")
    
    # Q1: 1 3 4 (Teacher 3 at week 4)
    # Before any rotations, T3->Class3 (0-based T2->C2). Output 3.
    val = await sys.send_query_1(d=3-1, x=4)
    if val != 3:
        raise TestFailure(f"Expected 3, got {val}")
    print(f"Q1: T3 at W4 = {val} (Exp 3) - PASS")

    # Q2: 0 2 2 3 2 (Rotate 3,2 at week 2)
    # Convert to 0-based: Rotate (2,1) at week 2
    await sys.send_query_0(k=2, x=2, p_list=[2, 1])
    print("Q2: Added rotation (3,2) at W2")

    # Q3: 1 3 2 (Teacher 3 at week 2)
    # At week 2, after rotation: T3 moves to where T2 was. 
    # Initial: T1:C1, T2:C2, T3:C3. 
    # Rot (3,2): T3->C2, T2->C3. 
    # So T3 is in C2. Output 2.
    val = await sys.send_query_1(d=3-1, x=2)
    if val != 2:
        raise TestFailure(f"Expected 2, got {val}")
    print(f"Q3: T3 at W2 = {val} (Exp 2) - PASS")

    # Q4: 1 2 4 (Teacher 2 at week 4)
    # T2 is in C3 (since it was swapped with T3). Output 3.
    val = await sys.send_query_1(d=2-1, x=4)
    if val != 3:
        raise TestFailure(f"Expected 3, got {val}")
    print(f"Q4: T2 at W4 = {val} (Exp 3) - PASS")

    # Q5: 1 1 4 (Teacher 1 at week 4)
    # T1 was not in rotation, remains in C1. Output 1.
    val = await sys.send_query_1(d=1-1, x=4)
    if val != 1:
        raise TestFailure(f"Expected 1, got {val}")
    print(f"Q5: T1 at W4 = {val} (Exp 1) - PASS")

    print("Test Case 1 Passed!")

    # Sample Input 2:
    # 3 4 6
    # 1 3 4
    # 0 2 2 3 2
    # 1 3 2
    # 0 3 3 3 1 2
    # 1 2 4
    # 1 1 4
    # Output: 3, 2, 2, 3
    
    await sys.reset() # Reset for clean slate
    print("
--- Test Case 2 ---")

    # Q1: 1 3 4 -> 3
    val = await sys.send_query_1(d=3-1, x=4)
    if val != 3: raise TestFailure(f"T2.1 Exp 3 got {val}")
    print(f"Q1: {val} (3) PASS")

    # Q2: 0 2 2 3 2 -> Rotate (3,2) at W2
    await sys.send_query_0(k=2, x=2, p_list=[2, 1])
    print("Q2: Rot (3,2) W2")

    # Q3: 1 3 2 -> 2
    val = await sys.send_query_1(d=3-1, x=2)
    if val != 2: raise TestFailure(f"T2.3 Exp 2 got {val}")
    print(f"Q3: {val} (2) PASS")

    # Q4: 0 3 3 3 1 2 -> Rotate (3,1,2) at W3
    # Convert: (2,0,1)
    await sys.send_query_0(k=3, x=3, p_list=[2, 0, 1])
    print("Q4: Rot (3,1,2) W3")

    # Q5: 1 2 4 -> 2
    # State at W4:
    # W1-2: T1:C1, T2:C3 (from prev rot), T3:C2
    # W3+: Rot (T3, T1, T2)
    # T3 -> where T1 was (C1)
    # T1 -> where T2 was (C3)
    # T2 -> where T3 was (C2)
    # So T2 is in Class 2. Output 2.
    val = await sys.send_query_1(d=2-1, x=4)
    if val != 2: raise TestFailure(f"T2.5 Exp 2 got {val}")
    print(f"Q5: {val} (2) PASS")

    # Q6: 1 1 4 -> 3
    # T1 is in C3. Output 3.
    val = await sys.send_query_1(d=1-1, x=4)
    if val != 3: raise TestFailure(f"T2.6 Exp 3 got {val}")
    print(f"Q6: {val} (3) PASS")

    print("Test Case 2 Passed!")
    print("All tests passed!")
