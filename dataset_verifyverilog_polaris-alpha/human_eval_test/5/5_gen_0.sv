module array_intersperse(
  input      [2:0]      length,
  input      [7:0]      delimeter,
  input      [3:0][7:0] input_array,
  output reg [3:0]      output_length,
  output reg [6:0][7:0] result_array
);

  always @* begin
    // Default all outputs to zero
    output_length = 4'd0;
    result_array  = '{default:8'd0};

    case (length)
      3'd0: begin
        output_length = 4'd0;
      end

      3'd1: begin
        output_length    = 4'd1;
        result_array[0]  = input_array[0];
      end

      3'd2: begin
        output_length    = 4'd3;
        result_array[0]  = input_array[0];
        result_array[1]  = delimeter;
        result_array[2]  = input_array[1];
      end

      3'd3: begin
        output_length    = 4'd5;
        result_array[0]  = input_array[0];
        result_array[1]  = delimeter;
        result_array[2]  = input_array[1];
        result_array[3]  = delimeter;
        result_array[4]  = input_array[2];
      end

      default: begin // 4 or more treated as 4
        output_length    = 4'd7;
        result_array[0]  = input_array[0];
        result_array[1]  = delimeter;
        result_array[2]  = input_array[1];
        result_array[3]  = delimeter;
        result_array[4]  = input_array[2];
        result_array[5]  = delimeter;
        result_array[6]  = input_array[3];
      end
    endcase
  end

endmodule