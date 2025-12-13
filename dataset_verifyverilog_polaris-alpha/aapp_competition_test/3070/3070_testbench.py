import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_train_refund(dut):
    """Test train refund eligibility calculator"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Test cases (scaled for N=2/3, M=max4)
    test_cases = [
        # Sample 1
        {
            'n':2, 'm':3,
            'station': [1,1,1],
            'depart':[1800,2000,2200],
            'arrive':[9000,9200,9400],
            'delay':[1800,1600,1400],
            'expected':1800
        },
        # Sample 2
        {
            'n':2, 'm':2,
            'station':[1,1],
            'depart':[1800,1900],
            'arrive':[3600,3600],
            'delay':[1800,1600],
            'expected':131071 # impossible
        },
        # Sample 3 (3 stations)
        {
            'n':3, 'm':2,
            'station':[1,2],
            'depart':[10,20],
            'arrive':[20,30],
            'delay':[1,0],
            'expected':10
        }
    ]
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for case in test_cases:
        dut.start.value = 0
        dut.num_stations.value = case['n'] - 1  # 0-based encoding (2→1)
        dut.num_trains.value = case['m']
        for i in range(4):  # Initialize all trains
            dut.train_station[i].value = case['station'][i] if i < case['m'] else 0
            dut.train_depart[i].value = case['depart'][i] if i < case['m'] else 0
            dut.train_arrive[i].value = case['arrive'][i] if i < case['m'] else 0
            dut.train_delay[i].value = case['delay'][i] if i < case['m'] else 0
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
        if dut.result.value == case['expected']:
            passed += 1
        else:
            dut._log.error(f"Case failed: Got {dut.result.value}, expected {case['expected']}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)