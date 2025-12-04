module snake_to_camel (
  input clk,
  input rst_n,
  input start,
  input [127:0] data_in,
  output reg [127:0] data_out,
  output reg done
);

  reg [3:0] input_index;
  reg [3:0] output_index;
  reg [1:0] underscore_count;
  reg capitalize_next;
  reg processing;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out <= 128'b0;
      done <= 1'b0;
      input_index <= 4'b0;
      output_index <= 4'b0;
      underscore_count <= 2'b0;
      capitalize_next <= 1'b0;
      processing <= 1'b0;
    end else begin
      done <= 1'b0;
      if (processing) begin
        reg [7:0] current_char = data_in[input_index*8 +:8];
        reg [7:0] out_char;
        reg skip_char = 1'b0;

        if (current_char == 8'h5F && underscore_count < 2'd2) begin
          underscore_count <= underscore_count + 1'd1;
          capitalize_next <= 1'b1;
          skip_char = 1'b1;
        end else begin
          if (capitalize_next || (input_index == 4'd0)) begin
            if (current_char >= 8'h61 && current_char <= 8'h7A) begin
              out_char = current_char - 8'h20;
            end else begin
              out_char = current_char;
            end
            if (capitalize_next) begin
              capitalize_next <= 1'b0;
            end
          end else begin
            out_char = current_char;
          end
        end

        if (!skip_char) begin
          data_out[output_index*8 +:8] <= out_char;
          output_index <= output_index + 1;
        end

        if (input_index < 4'd15) begin
          input_index <= input_index + 4'd1;
        end else begin
          done <= 1'b1;
          processing <= 1'b0;
        end
      end else if (start) begin
        processing <= 1'b1;
        input_index <= 4'd0;
        output_index <= 4'd0;
        underscore_count <= 2'd0;
        capitalize_next <= 1'b0;
        data_out <= 128'd0;
      end
    end
  end

endmodule