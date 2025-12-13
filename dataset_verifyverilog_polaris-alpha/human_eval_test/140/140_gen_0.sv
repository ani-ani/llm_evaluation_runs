module space_replacer (
  input        clk,
  input        rst_n,
  input        start,
  input  [127:0] text_in,
  output reg   done,
  output reg [127:0] text_out
);

  // State encoding
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE       = 2'b10;

  reg [1:0]  state, next_state;
  reg [4:0]  idx;          // 0..15 for processing, up to 17 total cycles
  reg [1:0]  space_cnt;    // counts consecutive spaces (saturates at 3)

  // Internal buffer to build output per character index
  reg [7:0] out_buf [0:15];

  integer i;

  // Unpack out_buf to text_out
  always @(*) begin
    for (i = 0; i < 16; i = i + 1) begin
      text_out[8*i +: 8] = out_buf[i];
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end
      PROCESSING: begin
        // After processing 16 characters and one finalize step
        // idx: 0..15 -> characters, idx==16 -> finalize, idx==17 -> go DONE
        if (idx == 5'd17)
          next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      done      <= 1'b0;
      idx       <= 5'd0;
      space_cnt <= 2'd0;
      for (i = 0; i < 16; i = i + 1) begin
        out_buf[i] <= 8'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          idx       <= 5'd0;
          space_cnt <= 2'd0;
          if (start) begin
            // 1-cycle setup: no character processed yet
            // idx remains 0, processing begins next cycle
          end
        end

        PROCESSING: begin
          done <= 1'b0;

          if (idx < 5'd16) begin
            // Process character at position idx
            // Extract input character
            // text_in[8*idx +: 8]
            reg [7:0] ch;
            ch = text_in[8*idx +: 8];

            if (ch == 8'h20) begin
              // Space character
              if (space_cnt < 2'd3)
                space_cnt <= space_cnt + 2'd1;
              else
                space_cnt <= space_cnt; // saturate at 3

              if (space_cnt == 2'd0) begin
                // First space -> underscore
                out_buf[idx] <= 8'h5F; // '_'
              end else if (space_cnt == 2'd1) begin
                // Second space -> underscore
                out_buf[idx] <= 8'h5F; // '_'
              end else begin
                // Third or more space -> hyphen
                out_buf[idx] <= 8'h2D; // '-'
              end
            end else begin
              // Non-space character
              out_buf[idx] <= ch;
              space_cnt    <= 2'd0; // reset consecutive space count
            end

            idx <= idx + 5'd1;

          end else begin
            // idx >= 16: finalize cycles
            // Hyphen persists implicitly since further spaces would have been
            // handled during processing; here we just move toward DONE.
            if (idx < 5'd17)
              idx <= idx + 5'd1;
          end
        end

        DONE: begin
          // Assert done for one cycle; outputs already in out_buf/text_out
          done      <= 1'b1;
          idx       <= 5'd0;
          space_cnt <= 2'd0;
        end

        default: begin
          done      <= 1'b0;
          idx       <= 5'd0;
          space_cnt <= 2'd0;
        end
      endcase
    end
  end

endmodule
