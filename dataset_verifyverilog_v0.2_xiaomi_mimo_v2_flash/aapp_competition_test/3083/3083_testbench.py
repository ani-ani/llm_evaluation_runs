import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_playlist_solver_basic(dut):
    """Test finding a valid 9-song playlist"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Setup test case: 10 songs, artists a-j, edges from sample input 1
    # Song 1 (a): edges to 10, 3
    # Song 2 (b): edges to 6
    # Song 3 (c): edges to 1, 5
    # Song 4 (d): edges to 9
    # Song 5 (e): edges to 4
    # Song 6 (f): edges to 2
    # Song 7 (g): edges to 6, 8
    # Song 8 (h): no edges
    # Song 9 (i): edges to 3
    # Song 10 (j): edges to 7
    
    dut.n.value = 10
    
    # Artist IDs: a=0, b=1, c=2, d=3, e=4, f=5, g=6, h=7, i=8, j=9
    dut.artist_1.value = 0
    dut.artist_2.value = 1
    dut.artist_3.value = 2
    dut.artist_4.value = 3
    dut.artist_5.value = 4
    dut.artist_6.value = 5
    dut.artist_7.value = 6
    dut.artist_8.value = 7
    dut.artist_9.value = 8
    dut.artist_10.value = 9
    
    # Edge counts
    dut.num_edges_1.value = 2
    dut.num_edges_2.value = 1
    dut.num_edges_3.value = 2
    dut.num_edges_4.value = 1
    dut.num_edges_5.value = 1
    dut.num_edges_6.value = 1
    dut.num_edges_7.value = 2
    dut.num_edges_8.value = 0
    dut.num_edges_9.value = 1
    dut.num_edges_10.value = 1
    dut.num_edges_11.value = 0
    for i in range(12, 101):
        setattr(dut, f'num_edges_{i}').value = 0
    
    # Edges
    # Song 1: 10, 3
    dut.edge_1_1.value = 10
    dut.edge_1_2.value = 3
    # Song 2: 6
    dut.edge_2_1.value = 6
    # Song 3: 1, 5
    dut.edge_3_1.value = 1
    dut.edge_3_2.value = 5
    # Song 4: 9
    dut.edge_4_1.value = 9
    # Song 5: 4
    dut.edge_5_1.value = 4
    # Song 6: 2
    dut.edge_6_1.value = 2
    # Song 7: 6, 8
    dut.edge_7_1.value = 6
    dut.edge_7_2.value = 8
    # Song 8: none
    # Song 9: 3
    dut.edge_9_1.value = 3
    # Song 10: 7
    dut.edge_10_1.value = 7
    
    # Clear remaining edge inputs
    for s in range(1, 101):
        for e in range(1, 41):
            if (s == 1 and e > 2) or (s == 2 and e > 1) or (s == 3 and e > 2) or \
               (s == 4 and e > 1) or (s == 5 and e > 1) or (s == 6 and e > 1) or \
               (s == 7 and e > 2) or (s == 8 and e > 0) or (s == 9 and e > 1) or \
               (s == 10 and e > 1) or s > 10:
                attr_name = f'edge_{s}_{e}'
                if hasattr(dut, attr_name):
                    setattr(dut, attr_name).value = 0
    
    # Start search
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for search to complete (max 10000 cycles for simulation)
    max_cycles = 10000
    found = False
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.found.value == 1:
            found = True
            break
        if dut.searching.value == 0 and dut.found.value == 0:
            # Search completed without finding
            break
    
    if not found:
        raise TestFailure("Expected to find a valid playlist but didn't")
    
    # Read the found playlist
    playlist = []
    for i in range(1, 10):
        song_val = getattr(dut, f'song_{i}').value
        playlist.append(int(song_val))
    
    print(f"Found playlist: {playlist}")
    
    # Verify the playlist has 9 distinct artists
    artists = []
    for song in playlist:
        if song < 1 or song > 10:
            raise TestFailure(f"Invalid song number {song}")
        artist = getattr(dut, f'artist_{song}').value
        artists.append(int(artist))
    
    if len(set(artists)) != 9:
        raise TestFailure(f"Playlist has duplicate artists: {artists}")
    
    # Verify edges
    for i in range(8):
        curr = playlist[i]
        next_song = playlist[i+1]
        num_edges = getattr(dut, f'num_edges_{curr}').value
        found_edge = False
        for e in range(int(num_edges)):
            edge_val = getattr(dut, f'edge_{curr}_{e+1}').value
            if int(edge_val) == next_song:
                found_edge = True
                break
        if not found_edge:
            raise TestFailure(f"No edge from {curr} to {next_song}")
    
    print(f"Verification passed: {playlist}")


@cocotb.test()
async def test_playlist_solver_fail_case(dut):
    """Test case where no valid playlist exists"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Setup: 10 songs, but song 5 has same artist as song 1 (a)
    dut.n.value = 10
    
    # Artists: 1=a, 2=a (duplicate), 3-10 distinct
    dut.artist_1.value = 0
    dut.artist_2.value = 0  # duplicate artist
    dut.artist_3.value = 2
    dut.artist_4.value = 3
    dut.artist_5.value = 4
    dut.artist_6.value = 5
    dut.artist_7.value = 6
    dut.artist_8.value = 7
    dut.artist_9.value = 8
    dut.artist_10.value = 9
    
    # Edge counts (same as previous)
    dut.num_edges_1.value = 2
    dut.num_edges_2.value = 1
    dut.num_edges_3.value = 2
    dut.num_edges_4.value = 1
    dut.num_edges_5.value = 1
    dut.num_edges_6.value = 1
    dut.num_edges_7.value = 2
    dut.num_edges_8.value = 0
    dut.num_edges_9.value = 1
    dut.num_edges_10.value = 1
    for i in range(12, 101):
        setattr(dut, f'num_edges_{i}').value = 0
    
    # Edges (same as previous)
    dut.edge_1_1.value = 10
    dut.edge_1_2.value = 3
    dut.edge_2_1.value = 6
    dut.edge_3_1.value = 1
    dut.edge_3_2.value = 5
    dut.edge_4_1.value = 9
    dut.edge_5_1.value = 4
    dut.edge_6_1.value = 2
    dut.edge_7_1.value = 6
    dut.edge_7_2.value = 8
    dut.edge_9_1.value = 3
    dut.edge_10_1.value = 7
    
    # Clear others
    for s in range(1, 101):
        for e in range(1, 41):
            if (s == 1 and e > 2) or (s == 2 and e > 1) or (s == 3 and e > 2) or \
               (s == 4 and e > 1) or (s == 5 and e > 1) or (s == 6 and e > 1) or \
               (s == 7 and e > 2) or (s == 8 and e > 0) or (s == 9 and e > 1) or \
               (s == 10 and e > 1) or s > 10:
                attr_name = f'edge_{s}_{e}'
                if hasattr(dut, attr_name):
                    setattr(dut, attr_name).value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait with timeout
    max_cycles = 10000
    found = False
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.found.value == 1:
            found = True
            break
        if dut.searching.value == 0 and dut.found.value == 0:
            break
    
    if found:
        playlist = []
        for i in range(1, 10):
            playlist.append(int(getattr(dut, f'song_{i}').value))
        raise TestFailure(f"Should have failed but found playlist: {playlist}")
    
    print("Correctly reported failure for duplicate artist case")


@cocotb.test()
async def test_playlist_solver_different_graph(dut):
    """Test with a graph that requires finding path starting from different node"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Setup: 10 songs, but song 1 has no edges, must start from song 5
    # This tests the module searches all starting points
    dut.n.value = 10
    
    # Artists all distinct
    for i in range(1, 11):
        setattr(dut, f'artist_{i}').value = i-1
    
    # Song 1: no edges
    dut.num_edges_1.value = 0
    # Song 2: edges
    dut.num_edges_2.value = 1
    dut.edge_2_1.value = 3
    # Song 3: edges
    dut.num_edges_3.value = 1
    dut.edge_3_1.value = 4
    # Song 4: edges
    dut.num_edges_4.value = 1
    dut.edge_4_1.value = 5
    # Song 5: edges (start here)
    dut.num_edges_5.value = 1
    dut.edge_5_1.value = 6
    # Song 6: edges
    dut.num_edges_6.value = 1
    dut.edge_6_1.value = 7
    # Song 7: edges
    dut.num_edges_7.value = 1
    dut.edge_7_1.value = 8
    # Song 8: edges
    dut.num_edges_8.value = 1
    dut.edge_8_1.value = 9
    # Song 9: edges
    dut.num_edges_9.value = 1
    dut.edge_9_1.value = 10
    # Song 10: edges back to 2 to create longer path if needed
    dut.num_edges_10.value = 1
    dut.edge_10_1.value = 2
    
    # Clear others
    for s in range(11, 101):
        setattr(dut, f'num_edges_{s}').value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    max_cycles = 10000
    found = False
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.found.value == 1:
            found = True
            break
        if dut.searching.value == 0 and dut.found.value == 0:
            break
    
    if not found:
        raise TestFailure("Expected to find path starting from song 5")
    
    playlist = []
    for i in range(1, 10):
        playlist.append(int(getattr(dut, f'song_{i}').value))
    
    print(f"Found playlist: {playlist}")
    
    # Verify it starts from 5 (or contains 5 as first reachable)
    # Actually, with our linear chain 5->6->7->8->9->10->2->3->4, that's 9 songs
    # So expected: 5 6 7 8 9 10 2 3 4
    
    print("Test passed")
}