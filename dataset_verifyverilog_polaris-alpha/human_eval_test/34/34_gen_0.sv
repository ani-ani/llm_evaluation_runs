module unique_sorted (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  d_in [7:0],
  output logic [7:0]  result [7:0],
  output logic [3:0]  count,
  output logic        done
);

  // Internal storage for sorting and deduplication
  logic [7:0] data_reg [7:0];
  logic [7:0] work     [7:0];
  logic [7:0] unique   [7:0];

  // Counters
  logic [5:0] cycle_cnt;      // 0..71
  logic [3:0] sort_i;         // outer loop index (0..7)
  logic [3:0] sort_j;         // inner loop index (0..7)
  logic [3:0] dedup_idx;      // index into sorted array (0..7)
  logic [3:0] unique_idx;     // number of unique elements written

  // State encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    SORT  = 2'b01,
    DEDUP = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Combinational next-state and control
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = SORT;
        end
      end
      SORT: begin
        // After 64 cycles of sort operations, move to DEDUP
        if (cycle_cnt == 6'd63) begin
          next_state = DEDUP;
        end
      end
      DEDUP: begin
        // 8 cycles for dedup (0..7)
        if (cycle_cnt == 6'd71) begin
          next_state = DONE;
        end
      end
      DONE: begin
        // Remain in DONE until next start; restart on new start
        if (start) begin
          next_state = SORT;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      cycle_cnt  <= 6'd0;
      sort_i     <= 4'd0;
      sort_j     <= 4'd0;
      dedup_idx  <= 4'd0;
      unique_idx <= 4'd0;
      done       <= 1'b0;
      count      <= 4'd0;
      // Clear arrays
      data_reg[0] <= 8'd0; data_reg[1] <= 8'd0; data_reg[2] <= 8'd0; data_reg[3] <= 8'd0;
      data_reg[4] <= 8'd0; data_reg[5] <= 8'd0; data_reg[6] <= 8'd0; data_reg[7] <= 8'd0;
      work[0]     <= 8'd0; work[1]     <= 8'd0; work[2]     <= 8'd0; work[3]     <= 8'd0;
      work[4]     <= 8'd0; work[5]     <= 8'd0; work[6]     <= 8'd0; work[7]     <= 8'd0;
      unique[0]   <= 8'd0; unique[1]   <= 8'd0; unique[2]   <= 8'd0; unique[3]   <= 8'd0;
      unique[4]   <= 8'd0; unique[5]   <= 8'd0; unique[6]   <= 8'd0; unique[7]   <= 8'd0;
      result[0]   <= 8'd0; result[1]   <= 8'd0; result[2]   <= 8'd0; result[3]   <= 8'd0;
      result[4]   <= 8'd0; result[5]   <= 8'd0; result[6]   <= 8'd0; result[7]   <= 8'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          count      <= 4'd0;
          cycle_cnt  <= 6'd0;
          sort_i     <= 4'd0;
          sort_j     <= 4'd0;
          dedup_idx  <= 4'd0;
          unique_idx <= 4'd0;

          // On start, load inputs into working registers
          if (start) begin
            data_reg[0] <= d_in[0];
            data_reg[1] <= d_in[1];
            data_reg[2] <= d_in[2];
            data_reg[3] <= d_in[3];
            data_reg[4] <= d_in[4];
            data_reg[5] <= d_in[5];
            data_reg[6] <= d_in[6];
            data_reg[7] <= d_in[7];

            work[0] <= d_in[0];
            work[1] <= d_in[1];
            work[2] <= d_in[2];
            work[3] <= d_in[3];
            work[4] <= d_in[4];
            work[5] <= d_in[5];
            work[6] <= d_in[6];
            work[7] <= d_in[7];
          end
        end

        SORT: begin
          done <= 1'b0;

          // One compare-swap per cycle implementing bubble sort
          // Map cycle_cnt (0..63) -> (sort_i, sort_j)
          if (cycle_cnt == 6'd0) begin
            sort_i <= 4'd0;
            sort_j <= 4'd0;
          end else begin
            // Update indices based on previous values
            if (sort_j < 4'd6 - sort_i) begin
              sort_j <= sort_j + 4'd1;
            end else begin
              sort_j <= 4'd0;
              sort_i <= sort_i + 4'd1;
            end
          end

          // Perform compare and swap for current (sort_j, sort_j+1)
          if (work[sort_j] > work[sort_j + 1]) begin
            logic [7:0] tmp;
            tmp                 = work[sort_j];
            work[sort_j]        <= work[sort_j + 1];
            work[sort_j + 1]    <= tmp;
          end

          // Increment global cycle counter
          cycle_cnt <= cycle_cnt + 6'd1;

          // When reaching 63, next_state will be DEDUP; prepare dedup indices
          if (cycle_cnt == 6'd63) begin
            dedup_idx  <= 4'd0;
            unique_idx <= 4'd0;
          end
        end

        DEDUP: begin
          done <= 1'b0;

          // Deduplication over 8 cycles (72 total cycles including sort)
          // For dedup_idx:
          //  - if dedup_idx == 0: always take first as unique
          //  - else: compare with previous sorted element

          if (dedup_idx == 4'd0) begin
            unique[0]   <= work[0];
            unique_idx  <= 4'd1;
          end else if (dedup_idx < 4'd8) begin
            if (work[dedup_idx] != work[dedup_idx - 1]) begin
              unique[unique_idx] <= work[dedup_idx];
              unique_idx         <= unique_idx + 4'd1;
            end
          end

          dedup_idx <= dedup_idx + 4'd1;
          cycle_cnt <= cycle_cnt + 6'd1;

          // At the final cycle (cycle_cnt == 71), latch results in DONE state
        end

        DONE: begin
          // Latch final unique results and count once upon entering DONE
          // When entering DONE from DEDUP, cycle_cnt is 71; keep stable
          done <= 1'b1;

          // Update count with unique_idx (number of unique elements)
          count <= unique_idx;

          // Drive result array with unique values; pad remaining with zeros
          result[0] <= (unique_idx > 4'd0) ? unique[0] : 8'd0;
          result[1] <= (unique_idx > 4'd1) ? unique[1] : 8'd0;
          result[2] <= (unique_idx > 4'd2) ? unique[2] : 8'd0;
          result[3] <= (unique_idx > 4'd3) ? unique[3] : 8'd0;
          result[4] <= (unique_idx > 4'd4) ? unique[4] : 8'd0;
          result[5] <= (unique_idx > 4'd5) ? unique[5] : 8'd0;
          result[6] <= (unique_idx > 4'd6) ? unique[6] : 8'd0;
          result[7] <= (unique_idx > 4'd7) ? unique[7] : 8'd0;

          // Hold counters; allow restart on start
          if (start) begin
            // Reinitialize for new operation
            cycle_cnt  <= 6'd0;
            sort_i     <= 4'd0;
            sort_j     <= 4'd0;
            dedup_idx  <= 4'd0;
            unique_idx <= 4'd0;

            data_reg[0] <= d_in[0];
            data_reg[1] <= d_in[1];
            data_reg[2] <= d_in[2];
            data_reg[3] <= d_in[3];
            data_reg[4] <= d_in[4];
            data_reg[5] <= d_in[5];
            data_reg[6] <= d_in[6];
            data_reg[7] <= d_in[7];

            work[0] <= d_in[0];
            work[1] <= d_in[1];
            work[2] <= d_in[2];
            work[3] <= d_in[3];
            work[4] <= d_in[4];
            work[5] <= d_in[5];
            work[6] <= d_in[6];
            work[7] <= d_in[7];

            done  <= 1'b0;
            count <= 4'd0;
          end
        end

        default: begin
          // Fallback safe state
          state      <= IDLE;
          cycle_cnt  <= 6'd0;
          sort_i     <= 4'd0;
          sort_j     <= 4'd0;
          dedup_idx  <= 4'd0;
          unique_idx <= 4'd0;
          done       <= 1'b0;
          count      <= 4'd0;
        end
      endcase
    end
  end

endmodule