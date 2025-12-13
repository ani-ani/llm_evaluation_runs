module space_inserter(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] char_in [0:15],
  input  [3:0] length,
  output reg [7:0] char_out [0:31],
  output reg [4:0] out_length,
  output reg done
);

  // Internal registers
  reg [3:0] in_idx;        // Index for input characters (0-15)
  reg [4:0] out_idx;       // Index for output characters (0-31)
  reg       processing;    // Indicates active processing phase

  // Synchronous logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      in_idx      <= 4'd0;
      out_idx     <= 5'd0;
      processing  <= 1'b0;
      done        <= 1'b0;
      out_length  <= 5'd0;
      // Initialize outputs to spaces
      integer i;
      for (i = 0; i < 32; i = i + 1) begin
        char_out[i] <= 8'h20;
      end
    end else begin
      // Default done low unless explicitly set
      done <= 1'b0;

      // Start condition: latch start when high and not already processing
      if (start && !processing) begin
        // Initialize for new transaction
        processing <= 1'b1;
        in_idx     <= 4'd0;
        out_idx    <= 5'd0;
        out_length <= 5'd0;
        // Clear outputs to spaces for this run
        integer j;
        for (j = 0; j < 32; j = j + 1) begin
          char_out[j] <= 8'h20;
        end
      end else if (processing) begin
        // Processing one character per clock
        if (in_idx < length) begin
          if (in_idx == 4'd0) begin
            // First character: copy directly
            char_out[out_idx] <= char_in[in_idx];
            out_idx <= out_idx + 5'd1;
            in_idx  <= in_idx  + 4'd1;
          end else begin
            // Subsequent characters: check for capital and preceding non-space
            reg [7:0] curr_char;
            reg [7:0] prev_char;
            curr_char = char_in[in_idx];
            prev_char = char_in[in_idx - 1];

            if ((curr_char >= 8'd65) && (curr_char <= 8'd90) && (prev_char != 8'd32)) begin
              // Insert space before capital
              char_out[out_idx] <= 8'd32;      // space
              out_idx <= out_idx + 5'd1;

              // Place current character in next position
              char_out[out_idx + 5'd1] <= curr_char;
              out_idx <= out_idx + 5'd2;
              in_idx  <= in_idx  + 4'd1;
            end else begin
              // No space insertion
              char_out[out_idx] <= curr_char;
              out_idx <= out_idx + 5'd1;
              in_idx  <= in_idx  + 4'd1;
            end
          end
        end else begin
          // All input characters processed
          processing <= 1'b0;
          out_length <= out_idx;
          done       <= 1'b1;
          // Unused positions already spaces
        end
      end
    end
  end

endmodule