module find_min_piles(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] strengths [0:7],
    output reg [3:0] result,
    output reg done
);

// State encoding
localparam [3:0] S0_IDLE = 4'd0;
localparam [3:0] S1_SORT_START = 4'd1;
localparam [3:0] S2_SORT_ACTIVE = 4'd2;
localparam [3:0] S3_SORT_DONE = 4'd3;
localparam [3:0] S4_PROCESS_BOX = 4'd4;
localparam [3:0] S5_CHECK_PILE = 4'd5;
localparam [3:0] S6_INCREMENT_PILE = 4'd6;
localparam [3:0] S7_NEW_PILE = 4'd7;
localparam [3:0] S8_DONE = 4'd8;

// Internal registers
reg [3:0] state;
reg [7:0] sorted [0:7];
reg [3:0] pile_heights [0:7];
reg [2:0] pass;
reg [2:0] i;
reg [2:0] current_box_index;
reg [2:0] current_pile_index;
reg [3:0] number_of_piles;
reg found;

integer j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S0_IDLE;
        result <= 4'd0;
        done <= 1'b0;
        pass <= 3'd0;
        i <= 3'd0;
        current_box_index <= 3'd0;
        current_pile_index <= 3'd0;
        number_of_piles <= 4'd0;
        found <= 1'b0;
        for (j = 0; j < 8; j = j + 1) begin
            sorted[j] <= 8'd0;
            pile_heights[j] <= 4'd0;
        end
    end else begin
        case (state)
            S0_IDLE: begin
                done <= 1'b0;
                if (start && n != 4'd0) begin
                    for (j = 0; j < 8; j = j + 1) begin
                        if (j < n)
                            sorted[j] <= strengths[j];
                        else
                            sorted[j] <= 8'hFF;
                        pile_heights[j] <= 4'd0;
                    end
                    pass <= 3'd0;
                    i <= 3'd0;
                    number_of_piles <= 4'd0;
                    state <= S1_SORT_START;
                end else if (start && n == 4'd0) begin
                    result <= 4'd0;
                    done <= 1'b1;
                    state <= S8_DONE;
                end
            end

            S1_SORT_START: begin
                if (n > 3'd1) begin
                    pass <= 3'd0;
                    i <= 3'd0;
                    state <= S2_SORT_ACTIVE;
                end else begin
                    state <= S3_SORT_DONE;
                end
            end

            S2_SORT_ACTIVE: begin
                if (pass < n - 1) begin
                    if (i < n - pass - 1) begin
                        if (sorted[i] > sorted[i + 1]) begin
                            sorted[i] <= sorted[i + 1];
                            sorted[i + 1] <= sorted[i];
                        end
                        i <= i + 1;
                        state <= S2_SORT_ACTIVE;
                    end else begin
                        i <= 3'd0;
                        pass <= pass + 1;
                        state <= S2_SORT_ACTIVE;
                    end
                end else begin
                    state <= S3_SORT_DONE;
                end
            end

            S3_SORT_DONE: begin
                for (j = 0; j < 8; j = j + 1) begin
                    pile_heights[j] <= 4'd0;
                end
                current_box_index <= 3'd0;
                number_of_piles <= 4'd0;
                state <= S4_PROCESS_BOX;
            end

            S4_PROCESS_BOX: begin
                if (current_box_index < n) begin
                    current_pile_index <= 3'd0;
                    found <= 1'b0;
                    state <= S5_CHECK_PILE;
                end else begin
                    result <= number_of_piles;
                    done <= 1'b1;
                    state <= S8_DONE;
                end
            end

            S5_CHECK_PILE: begin
                if (current_pile_index < number_of_piles) begin
                    if (pile_heights[current_pile_index] <= sorted[current_box_index]) begin
                        pile_heights[current_pile_index] <= pile_heights[current_pile_index] + 1;
                        found <= 1'b1;
                        state <= S6_INCREMENT_PILE;
                    end else begin
                        current_pile_index <= current_pile_index + 1;
                        state <= S5_CHECK_PILE;
                    end
                end else begin
                    if (!found) begin
                        state <= S7_NEW_PILE;
                    end else begin
                        state <= S6_INCREMENT_PILE;
                    end
                end
            end

            S6_INCREMENT_PILE: begin
                current_box_index <= current_box_index + 1;
                state <= S4_PROCESS_BOX;
            end

            S7_NEW_PILE: begin
                pile_heights[number_of_piles] <= 4'd1;
                number_of_piles <= number_of_piles + 1;
                state <= S6_INCREMENT_PILE;
            end

            S8_DONE: begin
                done <= 1'b0;
                if (!start)
                    state <= S0_IDLE;
            end

            default: state <= S0_IDLE;
        endcase
    end
end

endmodule