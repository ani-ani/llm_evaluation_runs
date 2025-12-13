module string_explosion_filter(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to begin processing
  input [127:0] input_str, // 16-byte input string (8-bit per char)
  input [31:0] explosion, // 4-byte explosion pattern (8-bit per char)
  input [2:0] str_len, // actual input length (0-15)
  input [1:0] exp_len, // actual explosion length (1-4)
  output reg [127:0] result_str, // processed output string
  output reg [3:0] out_len, // final string length (0-15)
  output reg done // high when processing completes
);

  // Internal state encoding
  localparam [2:0]
    S_IDLE    = 3'd0,
    S_LOAD    = 3'd1,
    S_ITER    = 3'd2,
    S_FINAL1  = 3'd3,
    S_FINAL2  = 3'd4,
    S_DONE    = 3'd5;

  reg [2:0] state, next_state;

  // Registered inputs (for timing + stability)
  reg [127:0] in_str_r;
  reg [31:0]  explosion_r;
  reg [2:0]   str_len_r;
  reg [1:0]   exp_len_r;

  // Working buffer: 16 bytes
  reg [7:0] buf [0:15];
  reg [3:0] cur_len;          // 0-16, but constrained by spec to 0-15

  // Explosion detection
  reg        any_match;
  reg [3:0]  match_pos;       // leftmost match position

  // Iteration counter for latency tracking (0-15 iterations)
  reg [3:0] iter_count;

  integer i;

  //------------------------------------------------------------
  // Input registering
  //------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_str_r     <= 128'd0;
      explosion_r  <= 32'd0;
      str_len_r    <= 3'd0;
      exp_len_r    <= 2'd0;
    end else begin
      // Inputs must be stable 1 cycle before start; capture on start pulse
      if (start) begin
        in_str_r    <= input_str;
        explosion_r <= explosion;
        str_len_r   <= str_len;
        exp_len_r   <= exp_len;
      end
    end
  end

  //------------------------------------------------------------
  // State register
  //------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
    end else begin
      state      <= next_state;
    end
  end

  //------------------------------------------------------------
  // Combinational explosion detection on current buffer
  //------------------------------------------------------------
  always @* begin
    any_match = 1'b0;
    match_pos = 4'd0;

    case (exp_len_r)
      2'd0: begin
        // Not valid per spec; treat as no match
        any_match = 1'b0;
      end
      2'd1: begin
        // Single-byte pattern
        for (i = 0; i < 16; i = i + 1) begin
          if (!any_match && (i < cur_len)) begin
            if (buf[i] == explosion_r[7:0]) begin
              any_match = 1'b1;
              match_pos = i[3:0];
            end
          end
        end
      end
      2'd2: begin
        // 2-byte pattern
        for (i = 0; i < 16; i = i + 1) begin
          if (!any_match && (i + 1 < cur_len)) begin
            if (buf[i]   == explosion_r[7:0] &&
                buf[i+1] == explosion_r[15:8]) begin
              any_match = 1'b1;
              match_pos = i[3:0];
            end
          end
        end
      end
      2'd3: begin
        // 3-byte pattern
        for (i = 0; i < 16; i = i + 1) begin
          if (!any_match && (i + 2 < cur_len)) begin
            if (buf[i]   == explosion_r[7:0]  &&
                buf[i+1] == explosion_r[15:8] &&
                buf[i+2] == explosion_r[23:16]) begin
              any_match = 1'b1;
              match_pos = i[3:0];
            end
          end
        end
      end
      default: begin
        // 4-byte pattern (exp_len_r == 3 -> spec says 1-4, but encoding here 0-3, so use default for 4)
        // Interpret exp_len_r==2'b11 as length 4
        for (i = 0; i < 16; i = i + 1) begin
          if (!any_match && (i + 3 < cur_len)) begin
            if (buf[i]   == explosion_r[7:0]   &&
                buf[i+1] == explosion_r[15:8]  &&
                buf[i+2] == explosion_r[23:16] &&
                buf[i+3] == explosion_r[31:24]) begin
              any_match = 1'b1;
              match_pos = i[3:0];
            end
          end
        end
      end
    endcase
  end

  //------------------------------------------------------------
  // Next state logic
  //------------------------------------------------------------
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_LOAD;
        end
      end

      S_LOAD: begin
        // After loading buffer, move to iteration (even if length 0)
        next_state = S_ITER;
      end

      S_ITER: begin
        // Each cycle: either remove one explosion or finish
        if (any_match && (iter_count < 4'd15)) begin
          // Another iteration needed
          next_state = S_ITER;
        end else begin
          // No more matches or reached max iterations
          next_state = S_FINAL1;
        end
      end

      S_FINAL1: begin
        // Prepare result_str and out_len
        next_state = S_FINAL2;
      end

      S_FINAL2: begin
        // Register final outputs
        next_state = S_DONE;
      end

      S_DONE: begin
        // Hold done high until next start
        if (start) begin
          next_state = S_LOAD;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  //------------------------------------------------------------
  // Sequential logic: buffer management, length, iter_count, outputs
  //------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_len    <= 4'd0;
      iter_count <= 4'd0;
      done       <= 1'b0;
      out_len    <= 4'd0;
      result_str <= 128'd0;

      for (i = 0; i < 16; i = i + 1) begin
        buf[i] <= 8'd0;
      end
    end else begin
      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          // Wait for start; buffer/content unchanged
        end

        S_LOAD: begin
          // Load working buffer from registered inputs
          // str_len_r is 0-15; treat as number of valid bytes
          cur_len    <= {1'b0, str_len_r};
          iter_count <= 4'd0;

          // Unpack in_str_r into buf[0]..buf[15]
          // input_str[7:0] is byte0, [15:8] byte1, ...
          buf[0]  <= in_str_r[7:0];
          buf[1]  <= in_str_r[15:8];
          buf[2]  <= in_str_r[23:16];
          buf[3]  <= in_str_r[31:24];
          buf[4]  <= in_str_r[39:32];
          buf[5]  <= in_str_r[47:40];
          buf[6]  <= in_str_r[55:48];
          buf[7]  <= in_str_r[63:56];
          buf[8]  <= in_str_r[71:64];
          buf[9]  <= in_str_r[79:72];
          buf[10] <= in_str_r[87:80];
          buf[11] <= in_str_r[95:88];
          buf[12] <= in_str_r[103:96];
          buf[13] <= in_str_r[111:104];
          buf[14] <= in_str_r[119:112];
          buf[15] <= in_str_r[127:120];
        end

        S_ITER: begin
          done <= 1'b0;

          if (any_match && (iter_count < 4'd15)) begin
            // Remove the leftmost explosion instance at match_pos
            // Compute effective explosion length (1-4) from exp_len_r
            // exp_len_r encoding: 1->1,2->2,3->3,0 or others -> treat as 4 per spec 1-4
            reg [2:0] e_len;
            e_len = 3'd4; // default 4
            if (exp_len_r == 2'd1) e_len = 3'd1;
            else if (exp_len_r == 2'd2) e_len = 3'd2;
            else if (exp_len_r == 2'd3) e_len = 3'd3;

            // Shift bytes after match region left by e_len positions
            // for indices >= match_pos + e_len
            for (i = 0; i < 16; i = i + 1) begin
              if (i < match_pos) begin
                buf[i] <= buf[i];
              end else if (i < cur_len - e_len) begin
                // shift source from i+e_len
                if (i + e_len < 16)
                  buf[i] <= buf[i + e_len];
                else
                  buf[i] <= 8'd0;
              end else begin
                // tail becomes don't care / zeroed
                buf[i] <= 8'd0;
              end
            end

            // Update current length
            if (cur_len > e_len[3:0])
              cur_len <= cur_len - e_len[3:0];
            else
              cur_len <= 4'd0;

            // Count this iteration
            iter_count <= iter_count + 4'd1;

          end else begin
            // No more matches or iteration limit reached; hold buffer
            iter_count <= iter_count;
            cur_len    <= cur_len;
          end
        end

        S_FINAL1: begin
          // Build result_str based on cur_len.
          // If cur_len == 0 -> output "FRULA\0" + padding zeros.
          // Else output buffer bytes then pad with zeros.
          if (cur_len == 4'd0) begin
            // "F" "R" "U" "L" "A" 0x00 then zeros
            result_str[7:0]     <= 8'h46; // 'F'
            result_str[15:8]    <= 8'h52; // 'R'
            result_str[23:16]   <= 8'h55; // 'U'
            result_str[31:24]   <= 8'h4C; // 'L'
            result_str[39:32]   <= 8'h41; // 'A'
            result_str[47:40]   <= 8'h00; // '\0'
            result_str[127:48]  <= {10{8'h00}};
            out_len             <= 4'd0;
          end else begin
            // Output remaining buffer
            // Pack buf[0]..buf[15] into result_str; pad beyond cur_len with 0
            for (i = 0; i < 16; i = i + 1) begin
              if (i < cur_len)
                result_str[i*8 +: 8] <= buf[i];
              else
                result_str[i*8 +: 8] <= 8'd0;
            end
            out_len <= cur_len;
          end
          done <= 1'b0;
        end

        S_FINAL2: begin
          // Hold result_str/out_len stable; prepare to assert done
          done <= 1'b0;
        end

        S_DONE: begin
          // Signal completion; keep outputs stable until next start
          done <= 1'b1;
        end

        default: begin
          // Safety
          done       <= 1'b0;
        end
      endcase
    end
  end

endmodule