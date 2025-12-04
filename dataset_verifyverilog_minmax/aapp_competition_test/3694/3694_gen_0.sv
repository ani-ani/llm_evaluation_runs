module stone_game_winner(
  input clk,
  input rst_n,
  input reg start,
  input reg [3:0] n,
  input reg [15:0] stones[7:0],
  output reg outcome,
  output reg done
);
  // Local parameters
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE = 2'b10;

  // Internal signals
  reg [1:0] state;
  reg [5:0] cycle_counter;
  reg [15:0] sorted[7:0];
  reg [15:0] temp_sw;
  reg [3:0] outer_cnt;
  reg [3:0] inner_cnt;
  reg sort_done;
  reg [3:0] n_reg;

  // Wires for sorted elements
  wire [15:0] s0 = sorted[0];
  wire [15:0] s1 = sorted[1];
  wire [15:0] s2 = sorted[2];
  wire [15:0] s3 = sorted[3];
  wire [15:0] s4 = sorted[4];
  wire [15:0] s5 = sorted[5];
  wire [15:0] s6 = sorted[6];
  wire [15:0] s7 = sorted[7];

  // Combinational logic for outcome computation
  logic [3:0] zero_cnt;
  logic [2:0] dup_groups;
  logic [15:0] dup_val;
  logic dup_minus_one_present;
  logic parity_out;
  logic lose;
  logic [15:0] dup_val_minus_one;

  always_comb begin
    if (sort_done) begin
      // Count zeros among the first n_reg elements
      zero_cnt = 0;
      if (n_reg > 0 && s0 == 0) zero_cnt = zero_cnt + 1;
      if (n_reg > 1 && s1 == 0) zero_cnt = zero_cnt + 1;
      if (n_reg > 2 && s2 == 0) zero_cnt = zero_cnt + 1;
      if (n_reg > 3 && s3 == 0) zero_cnt = zero_cnt + 1;
      if (n_reg > 4 && s4 == 0) zero_cnt = zero_cnt + 1;
      if (n_reg > 5 && s5 == 0) zero_cnt = zero_cnt + 1;
      if (n_reg > 6 && s6 == 0) zero_cnt = zero_cnt + 1;
      if (n_reg > 7 && s7 == 0) zero_cnt = zero_cnt + 1;

      // Detect duplicate groups
      dup_groups = 0;
      dup_val = 0;
      dup_minus_one_present = 0;
      // i = 1
      if (n_reg > 1 && s1 == s0) begin
         dup_groups = 1;
         dup_val = s0;
      end
      // i = 2
      if (n_reg > 2 && s2 == s1) begin
         if (s1 != s0) begin
            dup_groups = dup_groups + 1;
            dup_val = s1;
         end
      end
      // i = 3
      if (n_reg > 3 && s3 == s2) begin
         if (s2 != s1) begin
            dup_groups = dup_groups + 1;
            dup_val = s2;
         end
      end
      // i = 4
      if (n_reg > 4 && s4 == s3) begin
         if (s3 != s2) begin
            dup_groups = dup_groups + 1;
            dup_val = s3;
         end
      end
      // i = 5
      if (n_reg > 5 && s5 == s4) begin
         if (s4 != s3) begin
            dup_groups = dup_groups + 1;
            dup_val = s4;
         end
      end
      // i = 6
      if (n_reg > 6 && s6 == s5) begin
         if (s5 != s4) begin
            dup_groups = dup_groups + 1;
            dup_val = s5;
         end
      end
      // i = 7
      if (n_reg > 7 && s7 == s6) begin
         if (s6 != s5) begin
            dup_groups = dup_groups + 1;
            dup_val = s6;
         end
      end

      dup_val_minus_one = dup_val - 1;
      if (dup_groups == 1) begin
         if (n_reg > 0 && s0 == dup_val_minus_one) dup_minus_one_present = 1;
         else if (n_reg > 1 && s1 == dup_val_minus_one) dup_minus_one_present = 1;
         else if (n_reg > 2 && s2 == dup_val_minus_one) dup_minus_one_present = 1;
         else if (n_reg > 3 && s3 == dup_val_minus_one) dup_minus_one_present = 1;
         else if (n_reg > 4 && s4 == dup_val_minus_one) dup_minus_one_present = 1;
         else if (n_reg > 5 && s5 == dup_val_minus_one) dup_minus_one_present = 1;
         else if (n_reg > 6 && s6 == dup_val_minus_one) dup_minus_one_present = 1;
         else if (n_reg > 7 && s7 == dup_val_minus_one) dup_minus_one_present = 1;
      end else begin
         dup_minus_one_present = 0;
      end

      // Parity of adjusted sum: XOR of (sorted[i][0] XOR i[0]) for i=0..n-1
      parity_out = 1'b0;
      if (n_reg > 0) parity_out ^= s0[0] ^ 1'b0;
      if (n_reg > 1) parity_out ^= s1[0] ^ 1'b1;
      if (n_reg > 2) parity_out ^= s2[0] ^ 1'b0;
      if (n_reg > 3) parity_out ^= s3[0] ^ 1'b1;
      if (n_reg > 4) parity_out ^= s4[0] ^ 1'b0;
      if (n_reg > 5) parity_out ^= s5[0] ^ 1'b1;
      if (n_reg > 6) parity_out ^= s6[0] ^ 1'b0;
      if (n_reg > 7) parity_out ^= s7[0] ^ 1'b1;

      // Determine losing condition
      lose = (dup_groups > 1) || ((dup_groups == 1) && dup_minus_one_present) || (zero_cnt > 1);
    end else begin
      zero_cnt = 0;
      dup_groups = 0;
      dup_val = 0;
      dup_minus_one_present = 0;
      parity_out = 0;
      lose = 0;
    end
  end

  // Sequential logic (state machine and sorting)
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      outcome <= 1'b0;
      cycle_counter <= 6'd0;
      sort_done <= 1'b0;
      outer_cnt <= 4'd0;
      inner_cnt <= 4'd0;
      n_reg <= 4'd0;
      // Initialize sorted array
      for (int k = 0; k < 8; k++) begin
         sorted[k] <= 16'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
             state <= PROCESSING;
             n_reg <= n;
             sorted <= stones; // copy whole array
             cycle_counter <= 6'd0;
             outer_cnt <= 4'd0;
             inner_cnt <= 4'd0;
             // If only one pile, sorting is trivially done
             if (n_reg <= 4'd1) begin
                sort_done <= 1'b1;
             end else begin
                sort_done <= 1'b0;
             end
             outcome <= 1'b0;
             done <= 1'b0;
          end
        end
        PROCESSING: begin
          // Count cycles from start
          if (cycle_counter < 6'd40) cycle_counter <= cycle_counter + 1;

          // Perform bubble sort step if not already done
          if (!sort_done) begin
             // Compare and possibly swap adjacent elements
             if (sorted[inner_cnt] > sorted[inner_cnt+1]) begin
                temp_sw <= sorted[inner_cnt];
                sorted[inner_cnt] <= sorted[inner_cnt+1];
                sorted[inner_cnt+1] <= temp_sw;
             end
             // Increment inner counter
             inner_cnt <= inner_cnt + 1;
             // Check if current pass is complete
             if (inner_cnt == (n_reg - 1 - outer_cnt)) begin
                // End of this outer pass
                if (outer_cnt == (n_reg - 1)) begin
                   sort_done <= 1'b1;
                   outer_cnt <= 4'd0;
                   inner_cnt <= 4'd0;
                end else begin
                   outer_cnt <= outer_cnt + 1;
                   inner_cnt <= 4'd0;
                end
             end
          end

          // Update outcome based on combinational result
          outcome <= (lose ? 1'b0 : parity_out);

          // Transition to DONE after 40 cycles
          if (cycle_counter == 6'd40) begin
             state <= DONE;
             done <= 1'b1;
          end
        end
        DONE: begin
          // Keep done asserted
          done <= 1'b1;
          // outcome remains as last assigned
        end
      endcase
    end
  end

endmodule