import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_virus_spread(dut):
    """Scaled test cases for virus spread tracker"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Test case 1 (4 people, D=1):
    # Person1: 5-10, Person2: 1-3, Person3: 5-5, Person4: 7-7 (infected: [0])
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Setup inputs
    dut.initial_infected.value = 0b00000001  # Person1 infected
    dut.days.value = 1                      # D=1 day
    s = [5, 1, 5, 7, 0,0,0,0]
    t = [10,3,5,7,0,0,0,0]
    for i in range(8):
        dut.s[i].value = s[i] if i <4 else 0
        dut.t[i].value = t[i] if i <4 else 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait 3 cycles (1 + D) for D=1
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    # Check result (should infect person3 &4 at D=1)
    assert dut.infected_mask.value == 0b00001101, f"Test1 failed: got {dut.infected_mask.value.integer}"
    
    # Test case 2 (2 people, D=0): Initial infection only
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    dut.initial_infected.value = 0b00000001
    dut.days.value = 0
    dut.s[0].value = 0; dut.t[0].value = 100
    dut.s[1].value = 50; dut.t[1].value = 150
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await RisingEdge(dut.clk)  # 1 cycle processing
    await RisingEdge(dut.clk)  # output cycle
    assert dut.infected_mask.value == 0b00000001, f"Test2 failed: got {dut.infected_mask.value.integer}"
    
    # Test case 3 (4 people, D=2)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    dut.initial_infected.value = 0b00000001  # Person1
    dut.days.value = 2       # 2 days
    s = [0,2,1,3,0,0,0,0]   # Person1:0-4, Person2:2-6, Person3:1-3, Person4:3-5
    t = [4,6,3,5,0,0,0,0]
    for i in range(8):
        dut.s[i].value = s[i] if i <4 else 0
        dut.t[i].value = t[i] if i <4 else 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(4):  # 3 cycles for D=2 (1 init + 2 days + 1 output)
        await RisingEdge(dut.clk)
    
    # Day1: Person2,3 infected; Day2: Person4 infected
    assert dut.infected_mask.value == 0b00001111, f"Test3 failed: got {dut.infected_mask.value.integer}"
    
    dut._log.info("3/3 tests passed")