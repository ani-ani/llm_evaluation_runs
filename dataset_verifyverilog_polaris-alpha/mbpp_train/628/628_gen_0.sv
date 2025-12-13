module space_replacer(
  input        clk,
  input        rst_n,
  input        start,
  input  [127:0] in_str,
  output reg   done,
  output reg [383:0] out_str
);

  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE_ST    = 2'b10;

  reg [1:0]  state;
  reg [4:0]  char_idx;   // 0..15
  reg [8:0]  out_pos;    // bit index for next output byte (0..47 bytes => 0..47*8)

  wire [7:0] cur_char;

  // Extract current character (LSByte first)
  assign cur_char = in_str[8*char_idx +: 8];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      done     <= 1'b0;
      char_idx <= 5'd0;
      out_pos  <= 9'd0;
      out_str  <= {384{1'b0}};
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize for new processing
            char_idx <= 5'd0;
            out_pos  <= 9'd0;
            out_str  <= {384{1'b0}};
            state    <= PROCESSING;
          end
        end

        PROCESSING: begin
          // Process one character per cycle
          if (cur_char == 8'h20) begin
            // Write '%'
            if (out_pos <= 9'd376)
              out_str[out_pos +: 8] <= 8'h25;
            // Write '2'
            if (out_pos + 9'd8 <= 9'd376 + 9'd8)
              out_str[out_pos + 9'd8 +: 8] <= 8'h32;
            // Write '0'
            if (out_pos + 9'd16 <= 9'd376 + 9'd16)
              out_str[out_pos + 9'd16 +: 8] <= 8'h30;
            out_pos <= out_pos + 9'd24;
          end else begin
            // Pass-through character
            if (out_pos <= 9'd376)
              out_str[out_pos +: 8] <= cur_char;
            out_pos <= out_pos + 9'd8;
          end

          // Advance character index
          if (char_idx == 5'd15) begin
            state <= DONE_ST;
          end
          char_idx <= char_idx + 5'd1;
        end

        DONE_ST: begin
          // Output valid; pulse done for one cycle
          done  <= 1'b1;
          state <= IDLE;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule