module remove_uppercase(
  input  clk,
  input  rst_n,
  input  start,
  input  [127:0] str_in,
  output reg [127:0] str_out,
  output reg [4:0]  out_length,
  output reg        done
);

  // Internal registers
  reg [3:0]  idx;         // 0-15 character index
  reg [4:0]  out_pos;     // position for next output character (0-16)
  reg        busy;        // indicates processing in progress
  reg [127:0] str_latched; // latched input string

  // Extract current character (MSB-first, character 15 down to 0)
  wire [7:0] curr_char = str_latched[127 - idx*8 -: 8];

  // Determine if character is uppercase A-Z
  wire is_uppercase = (curr_char >= 8'h41) && (curr_char <= 8'h5A);

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      str_out    <= 128'd0;
      out_length <= 5'd0;
      done       <= 1'b0;
      idx        <= 4'd0;
      out_pos    <= 5'd0;
      busy       <= 1'b0;
      str_latched<= 128'd0;
    end else begin
      // Default
      done <= 1'b0;

      if (start && !busy) begin
        // Latch input and initialize for new operation
        str_latched <= str_in;
        str_out     <= 128'd0;
        out_length  <= 5'd0;
        idx         <= 4'd0;
        out_pos     <= 5'd0;
        busy        <= 1'b1;
      end else if (busy) begin
        // Process current character
        if (!is_uppercase) begin
          // Place character at next output position (left-aligned)
          str_out[127 - out_pos*8 -: 8] <= curr_char;
          out_pos <= out_pos + 5'd1;
        end

        // Move to next character
        if (idx == 4'd15) begin
          // Last character processed
          busy       <= 1'b0;
          done       <= 1'b1;         // one-cycle done pulse
          out_length <= out_pos;      // final count of valid chars
        end
        idx <= idx + 4'd1;
      end
    end
  end

endmodule