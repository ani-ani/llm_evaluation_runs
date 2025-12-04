module flatten_unique_numbers (
  input clk,
  input rst_n,
  input start,
  input [2:0][2:0][7:0] list_data,
  output reg [7:0] unique_array [0:7],
  output reg [2:0] unique_count,
  output reg done
);

  reg [255:0] seen;
  reg [3:0] index;
  reg processing;
  reg [7:0] current_element;

  always_comb begin : element_selector
    case (index)
      4'd0: current_element = list_data[0][0];
      4'd1: current_element = list_data[0][1];
      4'd2: current_element = list_data[0][2];
      4'd3: current_element = list_data[1][0];
      4'd4: current_element = list_data[1][1];
      4'd5: current_element = list_data[1][2];
      4'd6: current_element = list_data[2][0];
      4'd7: current_element = list_data[2][1];
      4'd8: current_element = list_data[2][2];
      default: current_element = 8'd0;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      seen <= 256'd0;
      unique_count <= 3'd0;
      done <= 1'b0;
      processing <= 1'b0;
      index <= 4'd0;
      for (int i = 0; i < 8; i++) begin
        unique_array[i] <= 8'd0;
      end
    end else begin
      if (processing) begin
        if (!seen[current_element]) begin
          seen[current_element] <= 1'b1;
          if (unique_count < 3'd7) begin
            unique_array[unique_count] <= current_element;
            unique_count <= unique_count + 1'b1;
          end
        end

        if (index == 4'd8) begin
          processing <= 1'b0;
          done <= 1'b1;
        end else begin
          index <= index + 1'b1;
        end
      end else if (start) begin
        seen <= 256'd0;
        unique_count <= 3'd0;
        done <= 1'b0;
        processing <= 1'b1;
        index <= 4'd0;
      end
    end
  end
endmodule