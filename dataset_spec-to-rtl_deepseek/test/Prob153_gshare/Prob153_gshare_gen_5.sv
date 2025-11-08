module TopModule (
  input   wire clk,
  input   wire areset,
  input   wire predict_valid,
  input   [6:0] predict_pc,
  output  reg predict_taken,
  output  reg [6:0] predict_history,
  input   wire train_valid,
  input   wire train_taken,
  input   wire train_mispredicted,
  input   [6:0] train_history,
  input   [6:0] train_pc
);

  reg [6:0] GHR;
  reg [1:0] pht [0:127];

  wire [6:0] predict_index = predict_pc ^ GHR;

  always_comb begin
    if (predict_valid) begin
      predict_taken = pht[predict_index][1];
      predict_history = GHR;
    end else begin
      predict_taken = 1'b0;
      predict_history = 7'b0;
    end
  end

  wire [6:0] next_ghr = (train_valid && train_mispredicted) ? {train_history[6:1], train_taken} :
                         predict_valid ? {GHR[6:1], predict_taken} :
                         GHR;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      GHR <= 7'b0;
      for (int i = 0; i < 128; i++) begin
        pht[i] <= 2'b01;
      end
    end else begin
      if (train_valid) begin
        wire [6:0] train_index = train_pc ^ train_history;
        case (pht[train_index])
          2'b00: pht[train_index] <= train_taken ? 2'b01 : 2'b00;
          2'b01: pht[train_index] <= train_taken ? 2'b10 : 2'b00;
          2'b10: pht[train_index] <= train_taken ? 2'b11 : 2'b01;
          2'b11: pht[train_index] <= train_taken ? 2'b11 : 2'b10;
        endcase
      end
      GHR <= next_ghr;
    end
  end

endmodule