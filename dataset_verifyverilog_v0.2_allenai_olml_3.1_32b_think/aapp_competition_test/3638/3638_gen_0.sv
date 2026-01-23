module pattern_probability_sorter (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_patterns,
    input [7:0] pattern_length,
    input [7:0][63:0] predictions,
    output reg [2:0] sorted_indices [7:0],
    output reg done
);

localparam N = 64;

reg [2:0] num_patterns_reg;
reg [7:0] pattern_length_reg;
reg [7:0][63:0] predictions_reg [8:0];
reg [3:0] state;
reg done_reg;
reg [31:0] score [7:0];
reg [7:0] sorted_indices_reg [7:0];

localparam [15:0] recip_lut [9:0] = {
    16'd0, 16'd100, 16'd50, 16'd33, 16'd25, 16'd20, 16'd15, 16'd10, 16'd5, 16'd0
};

always @(posedge clk) begin
    if (!rst_n) begin
        num_patterns_reg <= 3'b000;
        pattern_length_reg <= 8'b00000000;
        predictions_reg[0] <= 64'd0;
        predictions_reg[1] <= 64'd0;
        predictions_reg[2] <= 64'd0;
        predictions_reg[3] <= 64'd0;
        predictions_reg[4] <= 64'd0;
        predictions_reg[5] <= 64'd0;
        predictions_reg[6] <= 64'd0;
        predictions_reg[7] <= 64'd0;
        score[0] <=32'd0; score[1] <=32'd0; score[2] <=32'd0; score[3] <=32'd0;
        score[4] <=32'd0; score[5] <=32'd0; score[6] <=32'd0; score[7] <=32'd0;
        sorted_indices_reg[0] <=8'd0; sorted_indices_reg[1] <=8'd0; sorted_indices_reg[2] <=8'd0; sorted_indices_reg[3] <=8'd0;
        sorted_indices_reg[4] <=8'd0; sorted_indices_reg[5] <=8'd0; sorted_indices_reg[6] <=8'd0; sorted_indices_reg[7] <=8'd0;
        state <=4'd0;
        done_reg <=1'b0;
    end else if (start) begin
        if (state ==4'd0) begin
            num_patterns_reg <= num_patterns;
            pattern_length_reg <= pattern_length;
            predictions_reg[0] <= predictions[0];
            predictions_reg[1] <= predictions[1];
            predictions_reg[2] <= predictions[2];
            predictions_reg[3] <= predictions[3];
            predictions_reg[4] <= predictions[4];
            predictions_reg[5] <= predictions[5];
            predictions_reg[6] <= predictions[6];
            predictions_reg[7] <= predictions[7];
            state <=4'd1;
        end
        if (state ==4'd1) begin
            if (pattern_length_reg ==8'd1) score[0] = (N-1+1)*recip_lut[2];
            score[0] <=32'd0;
            sorted_indices_reg[0] <=8'd0;
            sorted_indices_reg[1] <=8'd0;
            sorted_indices_reg[2] <=8'd0;
            sorted_indices_reg[3] <=8'd0;
            sorted_indices_reg[4] <=8'd0;
            sorted_indices_reg[5] <=8'd0;
            sorted_indices_reg[6] <=8'd0;
            sorted_indices_reg[7] <=8'd0;
            state <=4'd2;
        end
    end
end

assign done = done_reg;
assign sorted_indices = sorted_indices_reg;

endmodule