module TopModule (
  input clk,
  input areset,
  input predict_valid,
  input [6:0] predict_pc,
  output predict_taken,
  output [6:0] predict_history,
  input train_valid,
  input train_taken,
  input train_mispredicted,
  input [6:0] train_history,
  input [6:0] train_pc
);
  reg [1:0] PHT [0:127];
  reg [6:0] GHR;

  wire [6:0] predict_index = predict_pc ^ GHR;
  wire [6:0] train_index = train_pc ^ train_history;
  
  assign predict_taken = PHT[predict_index][1];
  assign predict_history = GHR;

  always @(posedge clk or posedge areset) begin
    if (areset) begin : reset_block
      integer i;
      for (i=0; i<128; i=i+1)
        PHT[i] <= 2'b01;
      GHR <= 7'b0;
    end else begin
      if (train_valid) begin
        case (PHT[train_index])
          2'b00: PHT[train_index] <= train_taken ? 2'b01 : 2'b00;
          2'b01: PHT[train_index] <= train_taken ? 2'b10 : 2'b00;
          2'b10: PHT[train_index] <= train_taken ? 2'b11 : 2'b01;
          2'b11: PHT[train_index] <= train_taken ? 2'b11 : 2'b10;
        endcase
      end
      
      if (train_valid && train_mispredicted) begin
        GHR <= {train_history[6:0], train_taken};
      end else if (predict_valid) begin
        GHR <= {GHR[6:0], predict_taken};
      end
    end
  end
endmodule