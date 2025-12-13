module cycle_partition(
  input        clk,
  input        rst_n,
  input        start,
  input  [15:0] adj_matrix_flat,
  output reg   done,
  output reg   valid_partition, // 0 = valid partition exists, 1 = invalid
  output reg [3:0] node_list,   // nodes in first found cycle, LSB->MSB order
  output reg [1:0] cycle_size   // size of first cycle
);

  // Internal registers
  reg [15:0] adj_reg;
  reg [3:0]  used;
  reg        found;
  reg [3:0]  first_cycle_nodes;
  reg [1:0]  first_cycle_size;
  reg [3:0]  cycle_cnt;
  reg        busy;

  // Helpers for adjacency: bit index = from*4 + to
  function automatic bit edge;
    input [15:0] mat;
    input [1:0] f;
    input [1:0] t;
    begin
      edge = mat[{f,2'b00} + t];
    end
  endfunction

  // Partition search executed combinationally when triggered
  task automatic compute_partition;
    reg [15:0] m;
    reg [3:0]  used_l;
    reg [3:0]  cycle_mask;
    reg [1:0]  sz;
    reg [3:0]  fc_nodes;
    reg [1:0]  fc_size;
    reg        fc_valid;
    integer i,j,k;
    reg ok;
  begin
    m        = adj_reg;
    used_l   = 4'b0000;
    fc_valid = 1'b0;
    fc_nodes = 4'b0000;
    fc_size  = 2'b00;

    // Try to build first cycle containing node 0 with increasing size

    // 2-node cycles: 0<->1, 0<->2, 0<->3
    if (!fc_valid && edge(m,2'd0,2'd1) && edge(m,2'd1,2'd0)) begin
      fc_nodes = 4'b0011; // {n1,n0} = {1,0}
      fc_size  = 2'd2;
      fc_valid = 1'b1;
    end
    if (!fc_valid && edge(m,2'd0,2'd2) && edge(m,2'd2,2'd0)) begin
      fc_nodes = 4'b0101; // {2,0}
      fc_size  = 2'd2;
      fc_valid = 1'b1;
    end
    if (!fc_valid && edge(m,2'd0,2'd3) && edge(m,2'd3,2'd0)) begin
      fc_nodes = 4'b1001; // {3,0}
      fc_size  = 2'd2;
      fc_valid = 1'b1;
    end

    // 3-node cycles including node 0
    if (!fc_valid) begin
      // 0->1->2->0
      if (edge(m,2'd0,2'd1) && edge(m,2'd1,2'd2) && edge(m,2'd2,2'd0)) begin
        fc_nodes = 4'b0101; // {2,1,0} -> only 3 bits used
        fc_size  = 2'd3;
        fc_valid = 1'b1;
      end
      // 0->2->1->0
      else if (edge(m,2'd0,2'd2) && edge(m,2'd2,2'd1) && edge(m,2'd1,2'd0)) begin
        fc_nodes = 4'b0011; // {1,2,0}
        fc_size  = 2'd3;
        fc_valid = 1'b1;
      end
      // 0->1->3->0
      else if (edge(m,2'd0,2'd1) && edge(m,2'd1,2'd3) && edge(m,2'd3,2'd0)) begin
        fc_nodes = 4'b1011; // {3,1,0}
        fc_size  = 2'd3;
        fc_valid = 1'b1;
      end
      // 0->3->1->0
      else if (edge(m,2'd0,2'd3) && edge(m,2'd3,2'd1) && edge(m,2'd1,2'd0)) begin
        fc_nodes = 4'b0011; // {1,3,0}
        fc_size  = 2'd3;
        fc_valid = 1'b1;
      end
      // 0->2->3->0
      else if (edge(m,2'd0,2'd2) && edge(m,2'd2,2'd3) && edge(m,2'd3,2'd0)) begin
        fc_nodes = 4'b1101; // {3,2,0}
        fc_size  = 2'd3;
        fc_valid = 1'b1;
      end
      // 0->3->2->0
      else if (edge(m,2'd0,2'd3) && edge(m,2'd3,2'd2) && edge(m,2'd2,2'd0)) begin
        fc_nodes = 4'b0101; // {2,3,0}
        fc_size  = 2'd3;
        fc_valid = 1'b1;
      end
    end

    // 4-node Hamiltonian cycles
    if (!fc_valid) begin
      // 0->1->2->3->0
      if (edge(m,2'd0,2'd1) && edge(m,2'd1,2'd2) && edge(m,2'd2,2'd3) && edge(m,2'd3,2'd0)) begin
        fc_nodes = 4'b1111; // {3,2,1,0}
        fc_size  = 2'd4;
        fc_valid = 1'b1;
      end
      // 0->1->3->2->0
      else if (edge(m,2'd0,2'd1) && edge(m,2'd1,2'd3) && edge(m,2'd3,2'd2) && edge(m,2'd2,2'd0)) begin
        fc_nodes = 4'b1111; // {2,3,1,0}
        fc_size  = 2'd4;
        fc_valid = 1'b1;
      end
      // 0->2->1->3->0
      else if (edge(m,2'd0,2'd2) && edge(m,2'd2,2'd1) && edge(m,2'd1,2'd3) && edge(m,2'd3,2'd0)) begin
        fc_nodes = 4'b1111; // {3,1,2,0}
        fc_size  = 2'd4;
        fc_valid = 1'b1;
      end
      // 0->2->3->1->0
      else if (edge(m,2'd0,2'd2) && edge(m,2'd2,2'd3) && edge(m,2'd3,2'd1) && edge(m,2'd1,2'd0)) begin
        fc_nodes = 4'b1111; // {1,3,2,0}
        fc_size  = 2'd4;
        fc_valid = 1'b1;
      end
      // 0->3->1->2->0
      else if (edge(m,2'd0,2'd3) && edge(m,2'd3,2'd1) && edge(m,2'd1,2'd2) && edge(m,2'd2,2'd0)) begin
        fc_nodes = 4'b1111; // {2,1,3,0}
        fc_size  = 2'd4;
        fc_valid = 1'b1;
      end
      // 0->3->2->1->0
      else if (edge(m,2'd0,2'd3) && edge(m,2'd3,2'd2) && edge(m,2'd2,2'd1) && edge(m,2'd1,2'd0)) begin
        fc_nodes = 4'b1111; // {1,2,3,0}
        fc_size  = 2'd4;
        fc_valid = 1'b1;
      end
    end

    // If we did not find a cycle containing node 0, try other cycle structures
    // Priority: 2-cycles first, must cover all nodes exactly once.

    // If first cycle found above, verify remaining nodes form cycles as well
    if (fc_valid) begin
      // Mark used from first cycle mask derived from fc_nodes and fc_size
      // fc_nodes LSB->MSB hold node indices encoded as one-hot bit positions for simplicity
      used_l = 4'b0000;
      for (i = 0; i < 4; i = i + 1) begin
        if (fc_nodes[i]) used_l[i] = 1'b1;
      end

      // Now check remaining nodes form valid disjoint cycles
      cycle_mask = used_l;
      ok = 1'b1;

      // If all 4 already used, we're done
      if (cycle_mask != 4'b1111) begin
        // Remaining must form either a 2-cycle or a 3-cycle, depending on count
        case (cycle_mask)
          4'b0011: begin // nodes 2,3 remain
            if (!(edge(m,2'd2,2'd3) && edge(m,2'd3,2'd2))) ok = 1'b0;
          end
          4'b0101: begin // nodes 1,3 remain
            if (!(edge(m,2'd1,2'd3) && edge(m,2'd3,2'd1))) ok = 1'b0;
          end
          4'b0110: begin // nodes 0,3 remain (should not happen if 0 in first cycle)
            if (!(edge(m,2'd0,2'd3) && edge(m,2'd3,2'd0))) ok = 1'b0;
          end
          4'b1001: begin // nodes 1,2 remain
            if (!(edge(m,2'd1,2'd2) && edge(m,2'd2,2'd1))) ok = 1'b0;
          end
          4'b1010: begin // nodes 0,2 remain (should not happen)
            if (!(edge(m,2'd0,2'd2) && edge(m,2'd2,2'd0))) ok = 1'b0;
          end
          4'b1100: begin // nodes 0,1 remain (should not happen)
            if (!(edge(m,2'd0,2'd1) && edge(m,2'd1,2'd0))) ok = 1'b0;
          end
          default: begin
            // For other patterns, handle 3-node cycles among remaining
            // Enumerate all 3-node possibilities
            if (cycle_mask == 4'b0001) begin // remaining 1,2,3
              if (!(
                (edge(m,2'd1,2'd2)&&edge(m,2'd2,2'd3)&&edge(m,2'd3,2'd1)) ||
                (edge(m,2'd1,2'd3)&&edge(m,2'd3,2'd2)&&edge(m,2'd2,2'd1))
              )) ok = 1'b0;
            end else if (cycle_mask == 4'b0010) begin // remaining 0,2,3
              if (!(
                (edge(m,2'd0,2'd2)&&edge(m,2'd2,2'd3)&&edge(m,2'd3,2'd0)) ||
                (edge(m,2'd0,2'd3)&&edge(m,2'd3,2'd2)&&edge(m,2'd2,2'd0))
              )) ok = 1'b0;
            end else if (cycle_mask == 4'b0100) begin // remaining 0,1,3
              if (!(
                (edge(m,2'd0,2'd1)&&edge(m,2'd1,2'd3)&&edge(m,2'd3,2'd0)) ||
                (edge(m,2'd0,2'd3)&&edge(m,2'd3,2'd1)&&edge(m,2'd1,2'd0))
              )) ok = 1'b0;
            end else if (cycle_mask == 4'b1000) begin // remaining 0,1,2
              if (!(
                (edge(m,2'd0,2'd1)&&edge(m,2'd1,2'd2)&&edge(m,2'd2,2'd0)) ||
                (edge(m,2'd0,2'd2)&&edge(m,2'd2,2'd1)&&edge(m,2'd1,2'd0))
              )) ok = 1'b0;
            end else begin
              ok = 1'b0;
            end
          end
        endcase
      end

      if (ok) begin
        first_cycle_nodes = fc_nodes;
        first_cycle_size  = fc_size;
        found             = 1'b1;
      end else begin
        found             = 1'b0;
        first_cycle_nodes = 4'b0000;
        first_cycle_size  = 2'b00;
      end
    end else begin
      // No cycle containing node 0 found; for simplicity, declare invalid
      // (Exhaustive search could be added here if needed.)
      found             = 1'b0;
      first_cycle_nodes = 4'b0000;
      first_cycle_size  = 2'b00;
    end

    first_cycle_nodes = first_cycle_nodes;
    first_cycle_size  = first_cycle_size;
  end
  endtask

  // Main sequential control: enforce 10-cycle latency
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      adj_reg           <= 16'b0;
      done              <= 1'b0;
      valid_partition   <= 1'b1; // default invalid until proven
      node_list         <= 4'b0000;
      cycle_size        <= 2'b00;
      used              <= 4'b0000;
      found             <= 1'b0;
      first_cycle_nodes <= 4'b0000;
      first_cycle_size  <= 2'b00;
      cycle_cnt         <= 4'd0;
      busy              <= 1'b0;
    end else begin
      if (start && !busy) begin
        // Latch input and start 10-cycle delay
        adj_reg           <= adj_matrix_flat;
        done              <= 1'b0;
        valid_partition   <= 1'b1;
        node_list         <= 4'b0000;
        cycle_size        <= 2'b00;
        found             <= 1'b0;
        first_cycle_nodes <= 4'b0000;
        first_cycle_size  <= 2'b00;
        cycle_cnt         <= 4'd0;
        busy              <= 1'b1;
      end else if (busy) begin
        cycle_cnt <= cycle_cnt + 4'd1;

        if (cycle_cnt == 4'd8) begin
          // Perform computation so results are ready by cycle 10
          compute_partition();
        end

        if (cycle_cnt == 4'd9) begin
          // 10th cycle: output results
          done            <= 1'b1;
          if (found) begin
            valid_partition <= 1'b0; // 0 = valid
            node_list       <= first_cycle_nodes;
            cycle_size      <= first_cycle_size;
          end else begin
            valid_partition <= 1'b1; // 1 = invalid
            node_list       <= 4'b0000;
            cycle_size      <= 2'b00;
          end
          busy           <= 1'b0;
        end
      end else begin
        done <= 1'b0; // stay low until next operation completes
      end
    end
  end

endmodule