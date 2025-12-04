module quote_extractor (
  input clk,
  input rst_n,
  input start,
  input [63:0][7:0] text_input,
  output reg [7:0][15:0][7:0] extracted_strings,
  output reg [2:0] string_count,
  output reg done
);

  reg state; // 0: IDLE, 1: CAPTURING
  reg [5:0] byte_index;
  reg [3:0] current_char_index;
  reg processing;
  reg [3:0] internal_string_count;

  always_comb string_count = (internal_string_count >= 8) ? 3'd0 : internal_string_count[2:0];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 1'b0;
      byte_index <= 6'b0;
      current_char_index <= 4'b0;
      processing <= 1'b0;
      internal_string_count <= 4'b0;
      extracted_strings <= '0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;

      if (processing) begin
        // Capture logic
        case(state)
          1'b0: begin // IDLE
            if (text_input[byte_index] == 8'd34) begin // \" detected
              state <= 1'b1;
              if (internal_string_count < 4'd8) current_char_index <= 4'b0;
            end
          end
          1'b1: begin // CAPTURING
            if (text_input[byte_index] == 8'd34) begin // \" detected
              state <= 1'b0;
              if (internal_string_count < 4'd8) internal_string_count <= internal_string_count + 4'd1;
            end else if (internal_string_count < 4'd8 && current_char_index < 4'd15) begin
              extracted_strings[internal_string_count][current_char_index] <= text_input[byte_index];
              current_char_index <= current_char_index + 4'd1;
            end else if (internal_string_count < 4'd8 && current_char_index == 4'd15) begin
              extracted_strings[internal_string_count][current_char_index] <= text_input[byte_index];
            end
          end
        endcase

        // Completion check
        if (byte_index == 6'd63 || internal_string_count == 4'd8) begin
          // Finalize if still capturing last string
          if (state && internal_string_count < 4'd8) internal_string_count <= internal_string_count + 4'd1;
          processing <= 1'b0;
          done <= 1'b1;
        end else begin
          byte_index <= byte_index + 6'd1;
        end
      end else if (start) begin
        state <= 1'b0;
        byte_index <= 6'b0;
        current_char_index <= 4'b0;
        processing <= 1'b1;
        internal_string_count <= 4'b0;
        extracted_strings <= '0;
      end
    end
  end

endmodule