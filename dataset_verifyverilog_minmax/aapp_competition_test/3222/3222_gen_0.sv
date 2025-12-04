module cycle_partition (
  input clk,
  input rst_n,
  input start,                  // start computation
  input [15:0] adj_matrix_flat, // adjacency matrix flattened as 16 bits (4x4 graph)
  output reg done,              // high when computation complete
  output reg valid_partition,   // 0 = valid partition exists, 1 = impossible ("Yeah!")
  output reg [3:0] node_list,   // first cycle found (for test validation) LSB..MSB
  output reg [1:0] cycle_size   // size of first found cycle (2,3,4)
);

  // Flattened adjacency layout: 4x4 matrix, row major (row=0..3, col=0..3)
  // bit index = row*4 + col
  // diag assumed 0
  localparam ST_IDLE   = 4'b0000;
  localparam ST_LOAD   = 4'b0001;
  localparam ST_0      = 4'b0010;
  localparam ST_1      = 4'b0011;
  localparam ST_2      = 4'b0100;
  localparam ST_3      = 4'b0101;
  localparam ST_4      = 4'b0110;
  localparam ST_5      = 4'b0111;
  localparam ST_6      = 4'b1000;
  localparam ST_7      = 4'b1001;
  localparam ST_DONE   = 4'b1010;

  reg [3:0] state, next_state;
  reg [15:0] adj_flat_reg;
  reg found_pair;
  reg [1:0] pair_0, pair_1;      // up to two 2-cycles

  // One-hot encoding for 2-cycles when found
  wire [15:0] two_cycles_bits;
  assign two_cycles_bits = 16'b0000_0000_0000_0000; // placeholder; filled below via always comb

  // Helper to read adjacency (row r, col c)
  function [0:0] adj;
    input [1:0] r, c;
    integer idx;
    begin
      idx = r * 4 + c;
      adj = adj_flat_reg[idx];
    end
  endfunction

  // Determine if A->B->C path exists (A!=C; B!=C)
  function [0:0] path2;
    input [1:0] A, B, C;
    begin
      path2 = (adj(B, C) == 1'b1) && (A != C) && (B != C);
    end
  endfunction

  // Check if a 2-cycle A<->B exists
  function [0:0] two_cycle;
    input [1:0] A, B;
    begin
      two_cycle = (adj(A, B) == 1'b1) && (adj(B, A) == 1'b1);
    end
  endfunction

  // One-hot bits for the six possible 2-cycles
  // Order: (0,1), (0,2), (0,3), (1,2), (1,3), (2,3)
  reg [5:0] two_cycle_mask;
  always @(*) begin
    two_cycle_mask = 6'b0;
    if (two_cycle(2'd0, 2'd1)) two_cycle_mask[0] = 1'b1;
    if (two_cycle(2'd0, 2'd2)) two_cycle_mask[1] = 1'b1;
    if (two_cycle(2'd0, 2'd3)) two_cycle_mask[2] = 1'b1;
    if (two_cycle(2'd1, 2'd2)) two_cycle_mask[3] = 1'b1;
    if (two_cycle(2'd1, 2'd3)) two_cycle_mask[4] = 1'b1;
    if (two_cycle(2'd2, 2'd3)) two_cycle_mask[5] = 1'b1;
  end

  // State update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= ST_IDLE;
      adj_flat_reg <= 16'b0;
      found_pair <= 1'b0;
      pair_0     <= 2'b00;
      pair_1     <= 2'b00;
      done       <= 1'b0;
      valid_partition <= 1'b0;
      node_list  <= 4'b0000;
      cycle_size <= 2'b00;
    end else begin
      state <= next_state;
      case (state)
        ST_IDLE: begin
          done <= 1'b0;
          if (start) begin
            adj_flat_reg <= adj_matrix_flat;
            found_pair <= 1'b0;
            pair_0 <= 2'b00;
            pair_1 <= 2'b00;
          end
        end
        ST_LOAD: begin
          // Hold the matrix stable
        end
        ST_0: begin
          // Priority: 2-node cycles (search ordered pairs)
          found_pair <= 1'b0;
          pair_0 <= 2'b00;
          pair_1 <= 2'b00;
          if (two_cycle_mask[0]) begin
            found_pair <= 1'b1;
            pair_0 <= 2'b00; // 0<->1
            pair_1 <= 2'b11; // mark invalid initially
          end else if (two_cycle_mask[1]) begin
            found_pair <= 1'b1;
            pair_0 <= 2'd2;  // 0<->2
            pair_1 <= 2'b11;
          end else if (two_cycle_mask[2]) begin
            found_pair <= 1'b1;
            pair_0 <= 2'd3;  // 0<->3
            pair_1 <= 2'b11;
          end else if (two_cycle_mask[3]) begin
            found_pair <= 1'b1;
            pair_0 <= 2'b01; // 1<->2
            pair_1 <= 2'b11;
          end else if (two_cycle_mask[4]) begin
            found_pair <= 1'b1;
            pair_0 <= 2'b11; // 1<->3
            pair_1 <= 2'b11;
          end else if (two_cycle_mask[5]) begin
            found_pair <= 1'b1;
            pair_0 <= 2'b10; // 2<->3
            pair_1 <= 2'b11;
          end
        end
        ST_1: begin
          // If one 2-cycle found, try to find a disjoint second 2-cycle
          if (found_pair) begin
            // mask out bits used by pair_0
            case (pair_0)
              2'd0: begin
                // remove (0,1) -> bit 0
                if (two_cycle_mask[2] && !(pair_0==2'd2 || pair_0==2'd0)) begin found_pair <= 1'b1; pair_1 <= 2'd3; end else if (two_cycle_mask[3] && !(pair_0==2'd1 || pair_0==2'd2)) begin found_pair <= 1'b1; pair_1 <= 2'd1; end else if (two_cycle_mask[4] && !(pair_0==2'd1 || pair_0==2'd3)) begin found_pair <= 1'b1; pair_1 <= 2'b11; end else if (two_cycle_mask[5] && !(pair_0==2'd0 || pair_0==2'd2)) begin found_pair <= 1'b1; pair_1 <= 2'b10; end
              end
              2'd1: begin
                // remove (0,2) -> bit 1
                if (two_cycle_mask[2] && !(pair_0==2'd2 || pair_0==2'd0)) begin found_pair <= 1'b1; pair_1 <= 2'd3; end else if (two_cycle_mask[3] && !(pair_0==2'd1 || pair_0==2'd2)) begin found_pair <= 1'b1; pair_1 <= 2'b01; end else if (two_cycle_mask[4] && !(pair_0==2'd1 || pair_0==2'd3)) begin found_pair <= 1'b1; pair_1 <= 2'b11; end else if (two_cycle_mask[5] && !(pair_0==2'd0 || pair_0==2'd2)) begin found_pair <= 1'b1; pair_1 <= 2'b10; end
              end
              2'd2: begin
                // remove (0,3) -> bit 2
                if (two_cycle_mask[3] && !(pair_0==2'd1 || pair_0==2'd2)) begin found_pair <= 1'b1; pair_1 <= 2'b01; end else if (two_cycle_mask[4] && !(pair_0==2'd1 || pair_0==2'd3)) begin found_pair <= 1'b1; pair_1 <= 2'b11; end else if (two_cycle_mask[5] && !(pair_0==2'd0 || pair_0==2'd2)) begin found_pair <= 1'b1; pair_1 <= 2'b10; end
              end
              2'd3: begin
                // remove (1,2) -> bit 3
                if (two_cycle_mask[4] && !(pair_0==2'd1 || pair_0==2'd3)) begin found_pair <= 1'b1; pair_1 <= 2'b11; end else if (two_cycle_mask[5] && !(pair_0==2'd0 || pair_0==2'd2)) begin found_pair <= 1'b1; pair_1 <= 2'b10; end
              end
              default: begin
                // no additional action
              end
            endcase
          end
        end
        ST_2, ST_3, ST_4, ST_5, ST_6, ST_7: begin
          // No additional state updates required; we finalize in ST_DONE
        end
        ST_DONE: begin
          // Results already registered in this state
          done <= 1'b1;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    case (state)
      ST_IDLE: next_state = start ? ST_LOAD : ST_IDLE;
      ST_LOAD: next_state = ST_0;
      ST_0:    next_state = ST_1;
      ST_1:    next_state = ST_2;
      ST_2:    next_state = ST_3;
      ST_3:    next_state = ST_4;
      ST_4:    next_state = ST_5;
      ST_5:    next_state = ST_6;
      ST_6:    next_state = ST_7;
      ST_7:    next_state = ST_DONE;
      ST_DONE: next_state = ST_DONE;
      default: next_state = ST_IDLE;
    endcase
  end

  // Compute final outputs when done (1-cycle earlier than registered 'done' to align with requirement)
  always @(*) begin
    if (state == ST_DONE) begin
      // Start with default invalid unless proven otherwise
      valid_partition = 1'b1; // assume impossible unless proven otherwise
      node_list  = 4'b0000;
      cycle_size = 2'b00;

      // Check partitionability and record first cycle
      if (found_pair && pair_1 != 2'b11) begin
        // Two disjoint 2-cycles found => valid partition
        valid_partition = 1'b0;
        node_list = {1'b0, pair_0, 1'b0, pair_0}; // two copies of pair_0 to show 2 nodes
        cycle_size = 2'd2;
      end else if (found_pair) begin
        // Only one 2-cycle found => cannot cover all 4 nodes with 2-cycles alone
        // Try 4-cycle next (always 4 nodes)
        if (adj(2'd0,2'd1) && adj(2'd1,2'd2) && adj(2'd2,2'd3) && adj(2'd3,2'd0)) begin
          valid_partition = 1'b0; // 4-cycle exists => valid partition
          node_list = 4'b1100;    // 0,1,2,3 (LSB..MSB)
          cycle_size = 2'd4;
        end else begin
          // Not partitionable into cycles covering all nodes
          valid_partition = 1'b1; // impossible
          node_list = {1'b0, pair_0, 1'b0, pair_0}; // still report first found 2-cycle for test
          cycle_size = 2'd2;
        end
      end else begin
        // No 2-cycles. Try 4-cycle.
        if (adj(2'd0,2'd1) && adj(2'd1,2'd2) && adj(2'd2,2'd3) && adj(2'd3,2'd0)) begin
          valid_partition = 1'b0; // 4-cycle exists => valid partition
          node_list = 4'b1100;    // 0,1,2,3 (LSB..MSB)
          cycle_size = 2'd4;
        end else begin
          // No 2-cycle and no 4-cycle => no partition covering all nodes (impossible)
          valid_partition = 1'b1; // impossible
          node_list  = 4'b0000;
          cycle_size = 2'b00;
        end
      end
    end else begin
      // During computation, outputs mirror registered values (preliminary 0s)
      valid_partition = 1'b0;
      node_list  = 4'b0000;
      cycle_size = 2'b00;
    end
  end

endmodule
