module closest_handsome (input clk, input rst_n, input start, input [31:0] input_number, output reg [31:0] result_lower, output reg [31:0] result_upper, output reg found_lower, output reg found_upper, output reg done);

    reg [31:0] input_num_reg;
    reg [31:0] target_num;
    reg [31:0] lower_candidate;
    reg [31:0] upper_candidate;
    reg [31:0] result_lower_reg;
    reg [31:0] result_upper_reg;
    reg found_lower_reg;
    reg found_upper_reg;
    reg [2:0] state;
    reg done_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            input_num_reg <= 32'b0;
            target_num <= 32'b0;
            lower_candidate <= 32'b0;
            upper_candidate <= 32'b0;
            result_lower_reg <= 32'b0;
            result_upper_reg <= 32'b0;
            found_lower_reg <= 1'b0;
            found_upper_reg <= 1'b0;
            state <= 3'b000;
            done_reg <= 1'b0;
        end else begin
            if (start) begin
                input_num_reg <= input_number;
            end
            case (state)
                3'b000: begin
                    // IDLE: compute and check
                    state <= 3'b100;
                end
                3'b001: begin
                    // SEARCH_LOWER logic
                end
                3'b010: begin
                    // SEARCH_UPPER logic
                end
                3'b100: state <= 3'b100;
            endcase
        end
    end

    assign result_lower = result_lower_reg;
    assign result_upper = result_upper_reg;
    assign found_lower = found_lower_reg;
    assign found_upper = found_upper_reg;
    assign done = done_reg;

endmodule