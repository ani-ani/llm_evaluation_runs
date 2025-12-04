module space_inserter(input clk, input rst_n, input start, input [7:0] char_in [0:15], input [3:0] length, output reg [7:0] char_out [0:31], output reg [4:0] out_length, output reg done);
  reg processing;
  reg [4:0] cycle_count;
  reg [4:0] out_ptr;
  reg [7:0] last_char;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_out <= '{default: 8'h20};
      out_length <= 0;
      done <= 0;
      processing <= 0;
      cycle_count <= 0;
      out_ptr <= 0;
      last_char <= 0;
    end else begin
      done <= 0;
      if (processing) begin
        if (cycle_count < length) begin
          if (cycle_count == 0) begin
            char_out[out_ptr] <= char_in[0];
            last_char <= char_in[0];
            out_ptr <= out_ptr + 5'd1;
            out_length <= out_length + 5'd1;
          end else begin
            if ((char_in[cycle_count] >= 8'd65) && (char_in[cycle_count] <= 8'd90) && (last_char != 8'd32)) begin
              char_out[out_ptr] <= 8'h20;
              char_out[out_ptr + 1] <= char_in[cycle_count];
              last_char <= char_in[cycle_count];
              out_ptr <= out_ptr + 5'd2;
              out_length <= out_length + 5'd2;
            end else begin
              char_out[out_ptr] <= char_in[cycle_count];
              last_char <= char_in[cycle_count];
              out_ptr <= out_ptr + 5'd1;
              out_length <= out_length + 5'd1;
            end
          end
          cycle_count <= cycle_count + 5'd1;
        end else begin
          done <= 1;
          processing <= 0;
        end
      end else if (start) begin
        processing <= 1;
        cycle_count <= 0;
        out_ptr <= 0;
        last_char <= 0;
        out_length <= 0;
        char_out <= '{default: 8'h20};
      end
    end
  end
endmodule