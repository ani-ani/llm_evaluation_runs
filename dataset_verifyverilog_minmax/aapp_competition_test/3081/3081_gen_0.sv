module plane_scheduler (
  input clk,
  input rst_n,
  input start,
  input [15:0] inspect_time [0:3],
  input [15:0] flight_times [0:3][0:3],
  input [1:0] flight_s [0:3],
  input [1:0] flight_f [0:3],
  input [15:0] flight_t [0:3],
  output reg [2:0] plane_count,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE = 2'b00,
    CALC = 2'b01,
    DONE = 2'b10
  } state_t;

  state_t state;
  reg [7:0] counter;
  logic [3:0] can [0:3][0:3];
  logic [2:0] max_match_wire;

  // Combinational block to compute connectivity and maximum matching
  always_comb begin
    // Precompute connectivity matrix
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        if (i == j) begin
          can[i][j] = 1'b0;
        end else begin
          can[i][j] = (flight_t[j] >= flight_t[i] + 
                       flight_times[flight_f[i]][flight_f[j]] + 
                       inspect_time[flight_f[j]]);
        end
      end
    end

    // Compute maximum matching (brute force for 4 flights)
    max_match_wire = 0;
    
    // Check for matching of size 4
    for (int i0 = 0; i0 < 4; i0++) begin
      for (int i1 = 0; i1 < 4; i1++) begin
        if (i1 != i0) begin
          for (int i2 = 0; i2 < 4; i2++) begin
            if (i2 != i0 && i2 != i1) begin
              for (int i3 = 0; i3 < 4; i3++) begin
                if (i3 != i0 && i3 != i1 && i3 != i2) begin
                  if (can[0][i0] && can[1][i1] && can[2][i2] && can[3][i3]) begin
                    max_match_wire = 4;
                  end
                end
              end
            end
          end
        end
      end
    end

    // Check for matching of size 3
    if (max_match_wire < 4) begin
      for (int skip = 0; skip < 4; skip++) begin
        int lefts[3];
        int left_index = 0;
        for (int i = 0; i < 4; i++) begin
          if (i != skip) begin
            lefts[left_index] = i;
            left_index++;
          end
        end
        for (int perm0 = 0; perm0 < 3; perm0++) begin
          for (int perm1 = 0; perm1 < 3; perm1++) begin
            if (perm1 != perm0) begin
              for (int perm2 = 0; perm2 < 3; perm2++) begin
                if (perm2 != perm0 && perm2 != perm1) begin
                  if (can[lefts[0]][perm0] && can[lefts[1]][perm1] && can[lefts[2]][perm2]) begin
                    max_match_wire = 3;
                  end
                end
              end
            end
          end
        end
      end
    end

    // Check for matching of size 2
    if (max_match_wire < 3) begin
      for (int i0 = 0; i0 < 4; i0++) begin
        for (int i1 = 0; i1 < 4; i1++) begin
          if (i1 != i0) begin
            for (int perm0 = 0; perm0 < 4; perm0++) begin
              for (int perm1 = 0; perm1 < 4; perm1++) begin
                if (perm1 != perm0) begin
                  if (can[i0][perm0] && can[i1][perm1]) begin
                    max_match_wire = 2;
                  end
                end
              end
            end
          end
        end
      end
    end

    // Check for matching of size 1
    if (max_match_wire < 2) begin
      for (int i0 = 0; i0 < 4; i0++) begin
        for (int j0 = 0; j0 < 4; j0++) begin
          if (can[i0][j0]) begin
            max_match_wire = 1;
          end
        end
      end
    end
    // Matching of size 0 is always possible (no flights matched)
  end

  // Sequential logic for state machine and control
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 8'd0;
      plane_count <= 3'd0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC;
            counter <= 8'd0;
            done <= 1'b0;
          end
        end
        
        CALC: begin
          counter <= counter + 1;
          if (counter == 8'd0) begin
            plane_count <= 4 - max_match_wire;
          end
          if (counter == 8'd99) begin
            state <= DONE;
            done <= 1'b1;
          end
        end
        
        DONE: begin
          done <= 1'b1;
          if (start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end
endmodule