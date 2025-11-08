module TopModule(
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

	reg [1:0] pht [127:0];
	reg [6:0] global_history;

	wire [6:0] predict_index = predict_pc ^ global_history;
	wire [6:0] train_index = train_pc ^ train_history;

	assign predict_taken = predict_valid ? pht[predict_index][1] : 1'b0;
	assign predict_history = predict_valid ? global_history : 7'd0;

	always @(posedge clk or posedge areset) begin
		if (areset) begin
			global_history <= 7'd0;
			for (integer i = 0; i < 128; i = i + 1) begin
				pht[i] <= 2'b00;
			end
		end else begin
			// Update PHT
			if (train_valid) begin
				if (train_taken) begin
					if (pht[train_index] != 2'b11) begin
						pht[train_index] <= pht[train_index] + 1'b1;
					end
				end else begin
					if (pht[train_index] != 2'b00) begin
						pht[train_index] <= pht[train_index] - 1'b1;
					end
				end
			end
			// Update global_history
			if (train_valid && train_mispredicted) begin
				global_history <= {train_history[5:0], train_taken};
			end else if (predict_valid) begin
				global_history <= {global_history[5:0], predict_taken};
			end
		end
	end
endmodule