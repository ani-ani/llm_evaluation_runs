module TopModule(
  input  wire       clk,
  input  wire       areset,
  
  input  wire       predict_valid,
  input  wire [6:0] predict_pc,
  output logic      predict_taken,
  output logic [6:0] predict_history,
  
  input  wire       train_valid,
  input  wire       train_taken,
  input  wire       train_mispredicted,
  input  wire [6:0] train_history,
  input  wire [6:0] train_pc
);
  
  logic [6:0] ghr;
  logic [1:0] pht [0:127];
  
  // PHT update variables
  logic [6:0] train_idx;
  logic [1:0] updated_counter;
  
  // Saturing counter update function
  function [1:0] update_counter(input [1:0] counter, input taken);
    if (taken)
      update_counter = (counter == 2'b11) ? 2'b11 : counter + 1;
    else
      update_counter = (counter == 2'b00) ? 2'b00 : counter - 1;
  endfunction

  // Prediction Logic
  always_comb begin
    predict_history = ghr;
    if (predict_valid) begin
      logic [6:0] predict_idx = predict_pc ^ ghr;
      predict_taken = pht[predict_idx][1];
    end else begin
      predict_taken = 1'b0;
    end
  end

  // Training index calculation
  assign train_idx = train_pc ^ train_history;
  
  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      // Reset global history and PHT
      ghr <= 7'b0;
      for (int i = 0; i < 128; i++) begin
        pht[i] <= 2'b00;
      end
    end else begin
      // PHT update
      if (train_valid) begin
        pht[train_idx] <= update_counter(pht[train_idx], train_taken);
      end

      // Global history update (training has priority)
      if (train_valid && train_mispredicted) begin
        ghr <= {train_history[6:0], train_taken};
      end else if (train_valid) begin
        // Normal training updates history unless mispredicted takes priority
        ghr <= {ghr[6:0], train_taken};
      end else if (predict_valid) begin
        ghr <= {ghr[6:0], predict_taken};
      end
    end
  end

endmodule