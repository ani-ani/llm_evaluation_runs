module flatten_unique (
    input clk, rst_n, start,
    input [2:0][7:0] tuple_0,
    input [2:0][7:0] tuple_1,
    input [2:0][7:0] tuple_2,
    output reg [7:0] result_data,
    output reg [2:0] result_count,
    output reg done
  );

  // State Encoding
  localparam IDLE = 3'd0;
  localparam FETCH = 3'd1;
  localparam CHECK = 3'd2;
  localparam WRITE = 3'd3;
  localparam NEXT = 3'd4;
  localparam FINISH = 3'd5;

  // Internal Registers
  reg [2:0] state, next_state;
  reg [7:0] buffer [0:7]; // Unique storage (max 8 elements, though spec says up to 9, 8 is max capacity for 8 entries)
  reg [2:0] b_ptr;        // Points to next empty slot in buffer
  reg [2:0] s_ptr;        // Search pointer for current buffer element
  reg [2:0] t_idx;        // Index into current tuple (0, 1, 2)
  reg [7:0] current_val;  // Value being checked
  reg [2:0] tuple_sel;    // Selects which tuple to read (0, 1, 2)
  reg searching;          // Flag indicating we are in the middle of a search
  reg match_found;        // Signal if a match was found in current search cycle

  // Combinational logic for next state and outputs
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = FETCH;
      end
      FETCH: begin
        next_state = CHECK;
      end
      CHECK: begin
        if (match_found) begin
           next_state = NEXT; // Skip adding
        end else if (s_ptr == b_ptr) begin
           // End of buffer reached, no match found
           if (b_ptr < 8) next_state = WRITE; // Add if buffer not full
           else next_state = NEXT; // Buffer full, just move to next input
        end else begin
           next_state = CHECK; // Continue searching
        end
      end
      WRITE: begin
        next_state = NEXT;
      end
      NEXT: begin
        if (t_idx < 2) begin
          next_state = FETCH; // Get next element from same tuple
        end else if (tuple_sel < 2) begin
          next_state = FETCH; // Move to next tuple
        end else begin
          next_state = FINISH; // All done
        end
      end
      FINISH: begin
        next_state = FINISH;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential Logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result_data <= 8'b0;
      result_count <= 3'b0;
      done <= 1'b0;
      b_ptr <= 3'b0;
      s_ptr <= 3'b0;
      t_idx <= 3'b0;
      tuple_sel <= 3'b0;
      searching <= 1'b0;
      match_found <= 1'b0;
      // Initialize buffer (optional, but good practice)
      // buffer[0] <= 8'b0; ...
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            b_ptr <= 3'b0;
            result_count <= 3'b0;
            done <= 1'b0;
            tuple_sel <= 3'b0;
            t_idx <= 3'b0;
            searching <= 1'b0;
          end
        end

        FETCH: begin
          // Select current value based on tuple_sel and t_idx
          case (tuple_sel)
            3'd0: current_val <= tuple_0[t_idx];
            3'd1: current_val <= tuple_1[t_idx];
            3'd2: current_val <= tuple_2[t_idx];
          endcase
          s_ptr <= 3'b0;
          match_found <= 1'b0;
        end

        CHECK: begin
          if (s_ptr < b_ptr) begin
            // Compare with buffer[s_ptr]
            if (current_val == buffer[s_ptr]) begin
              match_found <= 1'b1;
            end else begin
              // Only increment s_ptr if we didn't just find a match and haven't finished searching implicitly by s_ptr < b_ptr check
              // The loop structure is s_ptr++, check match.
              // We handle s_ptr increment in NEXT or implicitly? 
              // Actually, let's increment s_ptr here for sequential search.
              // Wait, if we increment here, we need to handle the boundary correctly.
              // Let's increment s_ptr at the end of CHECK cycle if no match yet.
              s_ptr <= s_ptr + 1;
            end
          end
          // Note: logic inside ALWAYS block shouldn't depend on 'else if' flow for state transitions vs updates.
          // Updates happen regardless of state transition if not reset.
        end

        WRITE: begin
          // Add to buffer
          buffer[b_ptr] <= current_val;
          result_data <= current_val;
          result_count <= result_count + 1;
          b_ptr <= b_ptr + 1;
        end

        NEXT: begin
          // Increment indices
          if (t_idx < 2) begin
            t_idx <= t_idx + 1;
          end else begin
            // Reset index and move to next tuple
            t_idx <= 3'b0;
            if (tuple_sel < 2) begin
              tuple_sel <= tuple_sel + 1;
            end
          end
        end

        FINISH: begin
          done <= 1'b1;
        end
      endcase

      // Corrected Sequential Search Logic
      if (state == CHECK && next_state == CHECK) begin
        if (s_ptr < b_ptr) begin
          if (buffer[s_ptr] == current_val) begin
            match_found <= 1'b1;
          end else begin
            s_ptr <= s_ptr + 1;
          end
        end
      end
    end
  end
endmodule