module TopModule(input clk, input areset, input train_valid, input train_taken, output reg [1:0] state);
  always_ff @(posedge clk, posedge areset) begin
    if (areset) state <= 2'b01;
    else if (train_valid) begin
      case({train_taken, state})
        {1'b1, 2'b00}: state <= 2'b01;
        {1'b1, 2'b01}: state <= 2'b10;
        {1'b1, 2'b10}: state <= 2'b11;
        {1'b1, 2'b11}: state <= 2'b11;
        {1'b0, 2'b00}: state <= 2'b00;
        {1'b0, 2'b01}: state <= 2'b00;
        {1'b0, 2'b10}: state <= 2'b01;
        {1'b0, 2'b11}: state <= 2'b10;
      endcase
    end
  end
endmodule