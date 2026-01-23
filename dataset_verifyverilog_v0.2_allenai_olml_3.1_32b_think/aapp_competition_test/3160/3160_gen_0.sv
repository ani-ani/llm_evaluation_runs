module avg_operations (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_mask,
    input [7:0] head_mask,
    output reg [31:0] result_num,
    output reg [31:0] result_den,
    output reg done
);

reg [7:0] captured_char_mask;
reg [7:0] captured_head_mask;
reg [2:0] state;
reg [31:0] total_sum;
reg [7:0] config_idx;
reg [7:0] num_unknowns;
reg [31:0] denominator;
reg [7:0] current_value;
reg [7:0] steps;
reg [2:0] inner_state;
reg [3:0] k;
reg [7:0] temp_value;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        captured_char_mask <= 8'b0;
        captured_head_mask <= 8'b0;
        state <= 3'b0;
        total_sum <= 32'b0;
        config_idx <= 8'b0;
        num_unknowns <= 8'b0;
        denominator <= 32'b0;
        current_value <= 8'b0;
        steps <= 8'b0;
        inner_state <= 2'b0;
        k <= 4'b0;
        done <= 1'b0;
        result_num <= 32'b0;
        result_den <= 32'b0;
    end else begin
        case (state)
            3'b000: // IDLE
                if (start == 1) begin
                    captured_char_mask <= char_mask;
                    captured_head_mask <= head_mask;
                    config_idx <= 8'b0;
                    state <= 3'b001; // GENERATE_CONFIGS
                end
            3'b001: // GENERATE_CONFIGS
                if (config_idx < (1 << num_unknowns)) begin
                    current_value <= captured_head_mask;
                    state <= 3'b010; // CALCULATE_LENGTH
                end else begin
                    state <= 3'b011; // ACCUMULATE
                end
            3'b010: // CALCULATE_LENGTH
                steps <= 0;
                temp_value <= current_value;
                if (temp_value != 0) begin
                    steps <= steps + 1;
                    temp_value <= temp_value >> 1;
                end else begin
                    state <= 3'b011;
                end
            3'b011: // ACCUMULATE
                total_sum <= total_sum + steps;
                config_idx <= config_idx + 1;
                if (config_idx < (1 << num_unknowns)) begin
                    state <= 3'b001;
                end else begin
                    state <= 3'b100;
                end
            3'b100: // DIVIDE
                denominator <= 1 << num_unknowns;
                state <= 3'b101;
            3'b101: // DONE
                result_num <= total_sum;
                result_den <= denominator;
                done <= 1'b1;
        endcase
    end
end
endmodule