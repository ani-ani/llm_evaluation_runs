module max_quotation_level(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] a0,
  input [2:0] a1,
  input [2:0] a2,
  input [2:0] a3,
  input [2:0] a4,
  input [2:0] a5,
  input [2:0] a6,
  input [2:0] a7,
  output reg [2:0] k,
  output reg valid
);

  // Internal registers
  reg [2:0] state;
  reg [2:0] min_k;
  reg [2:0] candidate_k;
  reg [2:0] inner_target;       // candidate_k - 1
  reg [2:0] idx;                // index for inner segments
  reg       inner_ok;           // flag if inner segments satisfy condition
  reg [2:0] best_k;

  // State encoding
  localparam S_IDLE     = 3'd0;
  localparam S_SINGLE   = 3'd1;
  localparam S_INIT_N   = 3'd2;
  localparam S_CHECK_K  = 3'd3;
  localparam S_SCAN_INR = 3'd4;
  localparam S_DONE     = 3'd5;

  // Helper function: floor(log2(x)) for x in [0..7]
  function automatic [2:0] flog2_3b;
    input [2:0] x;
    begin
      case (x)
        3'd0: flog2_3b = 3'd0;
        3'd1: flog2_3b = 3'd0;
        3'd2: flog2_3b = 3'd1;
        3'd3: flog2_3b = 3'd1;
        3'd4: flog2_3b = 3'd2;
        3'd5: flog2_3b = 3'd2;
        3'd6: flog2_3b = 3'd2;
        3'd7: flog2_3b = 3'd2;
        default: flog2_3b = 3'd0;
      endcase
    end
  endfunction

  // Helper function: return segment value by index
  function automatic [2:0] get_seg;
    input [2:0] idx_f;
    begin
      case (idx_f)
        3'd0: get_seg = a0;
        3'd1: get_seg = a1;
        3'd2: get_seg = a2;
        3'd3: get_seg = a3;
        3'd4: get_seg = a4;
        3'd5: get_seg = a5;
        3'd6: get_seg = a6;
        3'd7: get_seg = a7;
        default: get_seg = 3'd0;
      endcase
    end
  endfunction

  // Sequential FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      k           <= 3'd0;
      valid       <= 1'b0;
      min_k       <= 3'd0;
      candidate_k <= 3'd0;
      inner_target<= 3'd0;
      idx         <= 3'd0;
      inner_ok    <= 1'b0;
      best_k      <= 3'd0;
    end else begin
      // Default
      valid <= 1'b0;

      case (state)
        S_IDLE: begin
          if (start) begin
            if (n == 3'd1) begin
              // Single segment case
              state <= S_SINGLE;
            end else begin
              // n > 1 case initialization
              state <= S_INIT_N;
            end
          end
        end

        // Handle n == 1
        S_SINGLE: begin
          if (a0 < 3'd2) begin
            k <= 3'd0;
          end else begin
            k <= flog2_3b(a0);
          end
          valid <= 1'b1;
          state <= S_DONE;
        end

        // Initialize for n > 1
        S_INIT_N: begin
          // min_k = min(a0, a_{n-1})
          begin
            reg [2:0] last_idx;
            reg [2:0] last_val;
            last_idx = n - 3'd1;
            last_val = get_seg(last_idx);
            if (a0 < last_val)
              min_k <= a0;
            else
              min_k <= last_val;
          end
          best_k      <= 3'd0;
          // start with candidate_k = min_k and search downward
          candidate_k <= 3'd0; // will be set next in S_CHECK_K after min_k resolves
          state       <= S_CHECK_K;
        end

        // Select next candidate_k or move to DONE
        S_CHECK_K: begin
          // Initialize candidate_k once from min_k if zero
          if (candidate_k == 3'd0)
            candidate_k <= min_k;
          else if (inner_ok == 1'b0) begin
            // previous candidate failed; try next lower
            if (candidate_k > 3'd1)
              candidate_k <= candidate_k - 3'd1;
            else
              candidate_k <= 3'd0; // will cause exit next
          end

          // If we already found working candidate in previous cycle
          if (inner_ok == 1'b1) begin
            best_k <= candidate_k;
            k      <= candidate_k;
            valid  <= 1'b1;
            state  <= S_DONE;
          end else begin
            // If candidate_k becomes 0, no valid k>0 found
            if (candidate_k == 3'd0) begin
              best_k <= 3'd0;
              k      <= 3'd0;
              valid  <= 1'b1;
              state  <= S_DONE;
            end else begin
              // Prepare to scan inner segments for this candidate_k
              inner_target <= candidate_k - 3'd1;
              idx          <= 3'd1; // start from segment 1
              inner_ok     <= 1'b1; // assume ok until violation
              state        <= S_SCAN_INR;
            end
          end
        end

        // Scan inner segments for current candidate_k
        S_SCAN_INR: begin
          // Inner segments are indices [1 .. n-2]
          if (idx >= (n - 3'd1)) begin
            // Completed scan for this candidate_k
            // inner_ok holds result
            state <= S_CHECK_K;
          end else begin
            if (get_seg(idx) < inner_target)
              inner_ok <= 1'b0;
            idx <= idx + 3'd1;
          end
        end

        S_DONE: begin
          // Hold result until next start
          if (start) begin
            if (n == 3'd1) begin
              state <= S_SINGLE;
            end else begin
              state <= S_INIT_N;
            end
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule