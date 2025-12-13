import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_dream_checker(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Event ID mapping for test cases
    event_map = {
        "business_as_usual": 0,
        "bobby_dies": 1,
        "stuff_happens": 2,
        "jr_does_bad_things": 3,
        "it_goes_on_and_on": 4,
        "bobby_died": 5  # Note: Different from bobby_dies
    }
    
    async def reset()
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.cmd.value = 0
        await RisingEdge(dut.clk)
    
    await reset()
    test_results = []
    
    # Helper to pack scenario data
    def pack_scenario(events):
        data = 0
        for i, e in enumerate(events):
            name = e.lstrip('!')
            is_neg = 1 if e.startswith('!') else 0
            ev_id = event_map.get(name, 0)
            data |= ((is_neg << 4) | ev_id) << (5*i)
        return data
    
    # Apply commands from first sample input
    commands = [
        ('E', 'business_as_usual', 0),
        ('E', 'bobby_dies', 0),
        ('S', ['bobby_died'], 1),
        ('E', 'stuff_happens', 0),
        ('E', 'jr_does_bad_things', 0),
        ('S', ['!bobby_dies', 'business_as_usual'], 2),
        ('E', 'it_goes_on_and_on', 0),
        ('D', 4, 0),
        ('S', ['!bobby_dies'], 1),
        ('S', ['!bobby_dies', 'it_goes_on_and_on'], 2)
    ]
    
    for cmd, data, k in commands:
        await RisingEdge(dut.clk)
        if cmd == 'E':
            dut.cmd.value = 1
            dut.data_in.value = event_map[data]
        elif cmd == 'D':
            dut.cmd.value = 2
            dut.data_in.value = data
        elif cmd == 'S':
            dut.cmd.value = 3
            dut.scenario_data.value = pack_scenario(data)
            await RisingEdge(dut.clk)
            while not dut.result_valid.value:
                await RisingEdge(dut.clk)
            res_type = dut.result_type.value.integer
            r = dut.dream_r.value.integer
            if res_type == 0:
                test_results.append("Plot Error")
            elif res_type == 1:
                test_results.append("Yes")
            elif res_type == 2:
                test_results.append(f"{r} Just A Dream")
            dut.cmd.value = 0
    
    # Verify results against expected output
    expected = ["Plot Error", "3 Just A Dream", "Yes", "Plot Error"]
    passed = 0
    for i, (res, exp) in enumerate(zip(test_results, expected)):
        if res == exp:
            passed += 1
        else:
            dut._log.error(f"Test {i} failed: Got {res}, expected {exp}")
    dut._log.info(f"{passed}/{len(expected)} tests passed")
