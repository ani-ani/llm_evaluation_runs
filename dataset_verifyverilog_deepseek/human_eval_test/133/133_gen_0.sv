module top_module (input clk, input reset, output reg [7:0] data_out);

  reg [7:0] data_in;
  wire [7:0] processed_data;

  // Instantiate the processing unit
  processing_unit pu ( .clk(clk), .reset(reset), .data_in(data_in), .data_out(processed_data) );

  // Assign output
  always @(posedge clk) begin
    if (reset) begin
      data_out <= 8'h00;
    end
    else begin
      data_out <= processed_data;
    end
  end

endmodule

module processing_unit (input clk, input reset, input [7:0] data_in, output reg [7:0] data_out);

  always @(posedge clk) begin
    if (reset) begin
      data_out <= 8'h00;
    end
    else begin
      data_out <= data_in + 1;
    end
  end

endmodule