module julia_betting(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] julia_score,
  input [63:0] p_scores,
  output reg [7:0] k,
  output reg done
);

  // State encoding
  localparam IDLE             = 2'b00;
  localparam COMPARE_DISTANCE = 2'b01; // (unused by name, kept for spec compliance)
  localparam SORTING          = 2'b10;
  localparam CALC_K           = 2'b11;

  reg [1:0] state, next_state;

  // Internal registers
  reg [7:0] opp [0:6];          // up to 7 opponent scores
  reg [2:0] opp_count;          // n-1

  integer i;

  // Sorting control
  reg [3:0] sort_step;          // supports up to 16 cycles window
  reg       sorted;

  // Calculation control
  reg [2:0] calc_idx;           // index over opponents
  reg [15:0] total;             // accumulate k, wide enough

  // sum_distances[i+1]: sum of differences (Julia - opp[j]) for j>i
  reg [15:0] sum_after;         // recomputed per i

  // pipeline / cycle budget tracking (to align with 16 cycles if desired)
  reg [4:0] cycle_cnt;

  // Extract opponent scores from p_scores on start
  // p_scores[63:56] is Julia, then 7 opponents: [55:48]...[7:0]
  wire [7:0] opp_raw [0:6];
  assign opp_raw[0] = p_scores[55:48];
  assign opp_raw[1] = p_scores[47:40];
  assign opp_raw[2] = p_scores[39:32];
  assign opp_raw[3] = p_scores[31:24];
  assign opp_raw[4] = p_scores[23:16];
  assign opp_raw[5] = p_scores[15:8];
  assign opp_raw[6] = p_scores[7:0];

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = SORTING; // COMPARE_DISTANCE placeholder; using SORTING directly
      end
      SORTING: begin
        if (sorted)
          next_state = CALC_K;
      end
      CALC_K: begin
        if (calc_idx == (opp_count))
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      done       <= 1'b0;
      k          <= 8'd0;
      opp_count  <= 3'd0;
      sort_step  <= 4'd0;
      sorted     <= 1'b0;
      calc_idx   <= 3'd0;
      total      <= 16'd0;
      cycle_cnt  <= 5'd0;
      for (i = 0; i < 7; i = i + 1) begin
        opp[i] <= 8'd0;
      end
    end else begin
      state <= next_state;

      done <= 1'b0; // default

      case (state)
        IDLE: begin
          if (start) begin
            // latch opponents based on n
            opp_count <= (n > 0) ? (n - 1) : 3'd0;
            for (i = 0; i < 7; i = i + 1) begin
              if (i < (n - 1))
                opp[i] <= opp_raw[i];
              else
                opp[i] <= 8'd0;
            end
            // init sorting
            sort_step <= 4'd0;
            sorted    <= ( (n <= 1) ? 1'b1 : 1'b0 );
            // init calc
            calc_idx  <= 3'd0;
            total     <= 16'd0;
            cycle_cnt <= 5'd0;
          end else begin
            // stay idle
            calc_idx  <= 3'd0;
            total     <= 16'd0;
            sort_step <= 4'd0;
            sorted    <= 1'b0;
          end
        end

        SORTING: begin
          cycle_cnt <= cycle_cnt + 5'd1;

          if (opp_count <= 1) begin
            sorted <= 1'b1;
          end else if (!sorted) begin
            // One bubble-sort pass per cycle (descending)
            for (i = 0; i < 6; i = i + 1) begin
              if (i < opp_count-1) begin
                if (opp[i] < opp[i+1]) begin
                  {opp[i], opp[i+1]} <= {opp[i+1], opp[i]};
                end
              end
            end

            sort_step <= sort_step + 4'd1;
            // Upper bound: (opp_count-1) passes are sufficient
            if (sort_step >= 4'd6) begin
              sorted <= 1'b1;
            end
          end
        end

        CALC_K: begin
          cycle_cnt <= cycle_cnt + 5'd1;

          if (calc_idx < opp_count) begin
            // compute sum_after = sum_{j=i+1}^{opp_count-1} (julia_score - opp[j])
            sum_after = 16'd0;
            for (i = 0; i < 7; i = i + 1) begin
              if ((i > calc_idx) && (i < opp_count)) begin
                if (julia_score >= opp[i])
                  sum_after = sum_after + (julia_score - opp[i]);
                else
                  sum_after = sum_after + 16'd0;
              end
            end

            // d = julia_score - opp[calc_idx]
            // treat negative as 0 (Julia already behind: zero guaranteed lead)
            if (julia_score >= opp[calc_idx]) begin
              // use signed 17-bit for intermediate
              reg [16:0] d;
              reg [16:0] tmp;
              d = julia_score - opp[calc_idx];
              if (d <= sum_after) begin
                // total += floor((sum_after - d + 1) / 2)
                tmp = sum_after - d + 17'd1;
                total <= total + (tmp[16:1]); // divide by 2
              end else begin
                total <= total + d[15:0];
              end
            end

            calc_idx <= calc_idx + 3'd1;
          end else begin
            // all done for i in [0..opp_count-1)
            // clamp to 8 bits for output
            k    <= (total[15:8] != 8'd0) ? 8'hFF : total[7:0];
            done <= 1'b1;
          end
        end

        default: ;
      endcase
    end
  end

endmodule