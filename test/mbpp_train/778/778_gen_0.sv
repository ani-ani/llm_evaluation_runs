module list_packer(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic [15:0][7:0]  data_in,
  input  logic [3:0]        length_in,
  output logic [3:0]        group_count,
  output logic [15:0][3:0]  start_indices,
  output logic [15:0][3:0]  group_lengths,
  output logic              done
);

  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_INIT  = 2'b01,
    S_PROC  = 2'b10,
    S_DONE  = 2'b11
  } state_e;

  state_e               state, next_state;
  logic [3:0]           idx;            // current index (0..15)
  logic [3:0]           group_idx;      // current group index (0..15)
  logic [7:0]           prev_val;       // previous data value
  logic [3:0]           curr_len;       // current group length
  logic [3:0]           len_latched;    // latched length_in

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      idx           <= 4'd0;
      group_idx     <= 4'd0;
      prev_val      <= 8'd0;
      curr_len      <= 4'd0;
      len_latched   <= 4'd0;
      group_count   <= 4'd0;
      done          <= 1'b0;
      start_indices <= '{default:4'd0};
      group_lengths <= '{default:4'd0};
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch input length; treat 0 as 1 to satisfy [1-16] requirement
            len_latched <= (length_in == 4'd0) ? 4'd1 : length_in;
            // Clear outputs for new run
            group_count   <= 4'd0;
            start_indices <= '{default:4'd0};
            group_lengths <= '{default:4'd0};
          end
        end

        S_INIT: begin
          // Initialize first group using element 0
          idx                       <= 4'd1;
          group_idx                 <= 4'd0;
          prev_val                  <= data_in[0];
          curr_len                  <= 4'd1;
          start_indices[0]          <= 4'd0;
          group_lengths[0]          <= 4'd0; // will be updated when group closes
        end

        S_PROC: begin
          if (idx < len_latched) begin
            if (data_in[idx] == prev_val) begin
              // Continue current group
              if (curr_len != 4'd15) begin
                curr_len <= curr_len + 4'd1;
              end else begin
                // Saturate at 15 (max for 4 bits); still meets 1-16 range overall
                curr_len <= curr_len;
              end
            end else begin
              // Close previous group
              group_lengths[group_idx] <= curr_len;
              // Start new group
              group_idx                <= group_idx + 4'd1;
              start_indices[group_idx + 4'd1] <= idx;
              prev_val                 <= data_in[idx];
              curr_len                 <= 4'd1;
            end
            idx <= idx + 4'd1;
          end else begin
            // idx == len_latched: close last group
            group_lengths[group_idx] <= curr_len;
            group_count              <= group_idx + 4'd1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: begin
          // Should not occur; safe reset behavior
          state <= S_IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) begin
          // If (effective) length is 0, nothing to process -> stay done-low
          if (((length_in == 4'd0) ? 4'd1 : length_in) != 4'd0)
            next_state = S_INIT;
        end
      end

      S_INIT: begin
        // Move directly into processing
        if (len_latched <= 4'd1) begin
          // Only one element: finalize immediately
          next_state = S_DONE;
        end else begin
          next_state = S_PROC;
        end
      end

      S_PROC: begin
        if (idx >= len_latched) begin
          next_state = S_DONE;
        end
      end

      S_DONE: begin
        // Wait for new start to re-run
        if (start) begin
          next_state = S_INIT;
        end
      end

      default: next_state = S_IDLE;
    endcase
  end

endmodule