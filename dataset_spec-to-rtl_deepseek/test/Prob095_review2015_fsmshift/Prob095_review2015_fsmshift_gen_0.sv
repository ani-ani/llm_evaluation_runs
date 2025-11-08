module TopModule(input clk, input reset, output shift_ena);
  reg [1:0] counter;
  reg counting;
  reg prev_reset;
  
  always_ff @(posedge clk) begin
    prev_reset <= reset;
  end
  
  wire start_counting = ~prev_reset && reset;
  
  always_ff @(posedge clk) begin
    if (start_counting) begin
      counting <= 1'b1;
      counter <= 2'b00;
    end else if (counting) begin
      if (counter == 2'b11)
        counting <= 1'b0;
      else
        counter <= counter + 1'b1;
    end
  end
  
  assign shift_ena = counting;
endmodule