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

  reg [6:0] global_history;
  reg [1:0] pht [0:127];

  // Wires for combinational logic
  wire [6:0] pred_index = predict_pc ^ global_history;
  wire pred_taken_wire = pht[pred_index][1];

  assign predict_taken = pred_taken_wire;
  assign predict_history = global_history;

  initial begin
    for (integer j = 0; j < 128; j = j + 1) pht[j] = 2'b01;
    global_history = 7'b0;
  end

  always @(posedge clk or posedge areset) begin
    if (areset) begin
      global_history <= 7'b0;
      for (integer j = 0; j < 128; j = j + 1) pht[j] <= 2'b01;
    end else begin
      if (train_valid) begin
        wire [6:0] train_index = train_pc ^ train_history;
        if (train_taken) begin
          if (pht[train_index] != 2'b11) pht[train_index] <= pht[train_index] + 1'b1;
        end else begin
          if (pht[train_index] != 2'b00) pht[train_index] <= pht[train_index] - 1'b1;
        end
      end
      
      if (train_valid && train_mispredicted) begin
        global_history <= {train_history, train_taken};
      end else if (predict_valid) begin
        global_history <= {global_history[5:0], pred_taken_wire};
      end
    end
  end

endmodule