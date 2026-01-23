import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_fog_catcher(dut):
    """Test the fog_catcher module with sample inputs."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.fog_count.value = 0
    for i in range(16):
        dut.fog_day[i].value = 0
        dut.fog_l[i].value = 0
        dut.fog_r[i].value = 0
        dut.fog_h[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')

    # Test Case 1: Example 1 from problem
    # Input: 2
    # 2 3 0 2 9 2 3 0
    # 1 6 1 4 6 3 -1 -2
    # Expected output: 3
    
    # We need to generate the events from the input lines
    # F1: m=2, d=3, l=0, r=2, h=9, dd=2, dx=3, dh=0
    #   Event 0: d=3, l=0, r=2, h=9
    #   Event 1: d=5, l=3, r=5, h=9
    # F2: m=1, d=6, l=1, r=4, h=6, dd=3, dx=-1, dh=-2
    #   Event 2: d=6, l=1, r=4, h=6
    
    # Total 3 events.
    # Processing:
    # 1. d=3, rect(0,2,9): No nets. Missed. Add Net(0,2,9). Count=1
    # 2. d=5, rect(3,5,9): Net(0,2,9) does not cover. Missed. Add Net(3,5,9). Count=2
    # 3. d=6, rect(1,4,6): Net(0,2,9) covers x=1,2 but height 9 > 6. Net(3,5,9) covers x=3,4. Combined cover [1,4].
    #   However, our simplified hardware checks for SINGLE NET containment or adding NEW net.
    #   Rect(1,4,6) is NOT inside Net(0,2,9) and NOT inside Net(3,5,9).
    #   So, our logic would count this as missed. Add Net(1,4,6). Count=3.
    #   Result: 3 matches.

    dut.fog_count.value = 3
    
    # Event 0 (d=3)
    dut.fog_day[0].value = 3
    dut.fog_l[0].value = 0
    dut.fog_r[0].value = 2
    dut.fog_h[0].value = 9
    
    # Event 1 (d=5)
    dut.fog_day[1].value = 5
    dut.fog_l[1].value = 3
    dut.fog_r[1].value = 5
    dut.fog_h[1].value = 9
    
    # Event 2 (d=6)
    dut.fog_day[2].value = 6
    dut.fog_l[2].value = 1
    dut.fog_r[2].value = 4
    dut.fog_h[2].value = 6
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Timeout waiting for done signal"
    assert dut.missed_count.value == 3, f"Expected 3 missed, got {dut.missed_count.value}"
    print(f"Test 1 Passed: Missed count = {dut.missed_count.value}")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test Case 2: Example 2
    # Input: 3
    # 4 0 0 10 10 1 15 0
    # 3 5 50 55 8 1 -16 2
    # 3 10 7 10 4 1 8 -1
    # Expected output: 6
    
    # Expand events:
    # F1: m=4, d=0, l=0, r=10, h=10, dd=1, dx=15, dh=0
    #   E0: d=0, l=0, r=10, h=10
    #   E1: d=1, l=15, r=25, h=10
    #   E2: d=2, l=30, r=40, h=10
    #   E3: d=3, l=45, r=55, h=10
    # F2: m=3, d=5, l=50, r=55, h=8, dd=1, dx=-16, dh=2
    #   E4: d=5, l=50, r=55, h=8
    #   E5: d=6, l=34, r=39, h=10
    #   E6: d=7, l=18, r=23, h=12
    # F3: m=3, d=10, l=7, r=10, h=4, dd=1, dx=8, dh=-1
    #   E7: d=10, l=7, r=10, h=4
    #   E8: d=11, l=15, r=18, h=3
    #   E9: d=12, l=23, r=26, h=2
    
    # Total 10 events. Hardware limit is 16, so OK.
    # Logic simulation:
    # 1. d=0 (0,10,10): Missed. Net(0,10,10). Count=1
    # 2. d=1 (15,25,10): Missed. Net(15,25,10). Count=2
    # 3. d=2 (30,40,10): Missed. Net(30,40,10). Count=3
    # 4. d=3 (45,55,10): Missed. Net(45,55,10). Count=4
    # 5. d=5 (50,55,8): Covered by Net(45,55,10). Not Missed.
    # 6. d=6 (34,39,10): Net(30,40,10) covers. Not Missed.
    # 7. d=7 (18,23,12): Missed. Net(18,23,12). Count=5
    # 8. d=10 (7,10,4): Net(0,10,10) covers. Not Missed.
    # 9. d=11 (15,18,3): Net(15,25,10) covers. Not Missed.
    # 10. d=12 (23,26,2): Net(15,25,10) covers x=23-25. Net(18,23,12) covers x=23. 
    #    Wait, Net(18,23,12) covers [18,23]. Input [23,26] touches at 23.
    #    Net(15,25,10) covers [15,25]. Input [23,26] covers 23-25 inside, 26 outside.
    #    So [23,26] is NOT fully covered by Net(15,25,10).
    #    Is it covered by combined? 23 is covered by Net(18,23,12) [height 12 > 2].
    #    24-25 covered by Net(15,25,10) [height 10 > 2].
    #    26 uncovered.
    #    So Missed. Add Net(23,26,2). Count=6.
    
    dut.fog_count.value = 10
    # Set inputs...
    # E0
    dut.fog_day[0].value = 0; dut.fog_l[0].value = 0; dut.fog_r[0].value = 10; dut.fog_h[0].value = 10
    # E1
    dut.fog_day[1].value = 1; dut.fog_l[1].value = 15; dut.fog_r[1].value = 25; dut.fog_h[1].value = 10
    # E2
    dut.fog_day[2].value = 2; dut.fog_l[2].value = 30; dut.fog_r[2].value = 40; dut.fog_h[2].value = 10
    # E3
    dut.fog_day[3].value = 3; dut.fog_l[3].value = 45; dut.fog_r[3].value = 55; dut.fog_h[3].value = 10
    # E4
    dut.fog_day[4].value = 5; dut.fog_l[4].value = 50; dut.fog_r[4].value = 55; dut.fog_h[4].value = 8
    # E5
    dut.fog_day[5].value = 6; dut.fog_l[5].value = 34; dut.fog_r[5].value = 39; dut.fog_h[5].value = 10
    # E6
    dut.fog_day[6].value = 7; dut.fog_l[6].value = 18; dut.fog_r[6].value = 23; dut.fog_h[6].value = 12
    # E7
    dut.fog_day[7].value = 10; dut.fog_l[7].value = 7; dut.fog_r[7].value = 10; dut.fog_h[7].value = 4
    # E8
    dut.fog_day[8].value = 11; dut.fog_l[8].value = 15; dut.fog_r[8].value = 18; dut.fog_h[8].value = 3
    # E9
    dut.fog_day[9].value = 12; dut.fog_l[9].value = 23; dut.fog_r[9].value = 26; dut.fog_h[9].value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.done.value == 1, "Timeout waiting for done signal"
    assert dut.missed_count.value == 6, f"Expected 6 missed, got {dut.missed_count.value}"
    print(f"Test 2 Passed: Missed count = {dut.missed_count.value}")
    
    print("All tests passed!")
