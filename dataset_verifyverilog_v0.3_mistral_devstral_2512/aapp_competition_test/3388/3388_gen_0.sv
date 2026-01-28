module betting_guarantee(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] julia_score,
    input wire [31:0] other_scores_0,
    input wire [31:0] other_scores_1,
    input wire [31:0] other_scores_2,
    input wire [31:0] other_scores_3,
    input wire [31:0] other_scores_4,
    input wire [31:0] other_scores_5,
    input wire [31:0] other_scores_6,
    input wire [31:0] other_scores_7,
    input wire [2:0] valid_count,
    output reg [31:0] guarantee_matches,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [31:0] max_score;
    reg [31:0] second_max_score;
    reg [31:0] count_max;
    reg [3:0] stage;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            max_score <= 32'd0;
            second_max_score <= 32'd0;
            count_max <= 32'd0;
            guarantee_matches <= 32'd0;
            done <= 1'b0;
            stage <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                end
            end
            PROCESS: begin
                if (stage == 4'd8) begin
                    next_state = CALCULATE;
                end
            end
            CALCULATE: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage <= 4'd0;
            cycle_count <= 8'd0;
        end else if (state == PROCESS) begin
            cycle_count <= cycle_count + 8'd1;
            case (stage)
                4'd0: begin
                    if (valid_count > 0) begin
                        max_score <= other_scores_0;
                        second_max_score <= 32'd0;
                        count_max <= 32'd1;
                    end else begin
                        max_score <= 32'd0;
                        second_max_score <= 32'd0;
                        count_max <= 32'd0;
                    end
                    stage <= 4'd1;
                end
                4'd1: begin
                    if (valid_count > 1) begin
                        if (other_scores_1 > max_score) begin
                            second_max_score <= max_score;
                            max_score <= other_scores_1;
                            count_max <= 32'd1;
                        end else if (other_scores_1 == max_score) begin
                            count_max <= count_max + 32'd1;
                        end else if (other_scores_1 > second_max_score && other_scores_1 < max_score) begin
                            second_max_score <= other_scores_1;
                        end
                    end
                    stage <= 4'd2;
                end
                4'd2: begin
                    if (valid_count > 2) begin
                        if (other_scores_2 > max_score) begin
                            second_max_score <= max_score;
                            max_score <= other_scores_2;
                            count_max <= 32'd1;
                        end else if (other_scores_2 == max_score) begin
                            count_max <= count_max + 32'd1;
                        end else if (other_scores_2 > second_max_score && other_scores_2 < max_score) begin
                            second_max_score <= other_scores_2;
                        end
                    end
                    stage <= 4'd3;
                end
                4'd3: begin
                    if (valid_count > 3) begin
                        if (other_scores_3 > max_score) begin
                            second_max_score <= max_score;
                            max_score <= other_scores_3;
                            count_max <= 32'd1;
                        end else if (other_scores_3 == max_score) begin
                            count_max <= count_max + 32'd1;
                        end else if (other_scores_3 > second_max_score && other_scores_3 < max_score) begin
                            second_max_score <= other_scores_3;
                        end
                    end
                    stage <= 4'd4;
                end
                4'd4: begin
                    if (valid_count > 4) begin
                        if (other_scores_4 > max_score) begin
                            second_max_score <= max_score;
                            max_score <= other_scores_4;
                            count_max <= 32'd1;
                        end else if (other_scores_4 == max_score) begin
                            count_max <= count_max + 32'd1;
                        end else if (other_scores_4 > second_max_score && other_scores_4 < max_score) begin
                            second_max_score <= other_scores_4;
                        end
                    end
                    stage <= 4'd5;
                end
                4'd5: begin
                    if (valid_count > 5) begin
                        if (other_scores_5 > max_score) begin
                            second_max_score <= max_score;
                            max_score <= other_scores_5;
                            count_max <= 32'd1;
                        end else if (other_scores_5 == max_score) begin
                            count_max <= count_max + 32'd1;
                        end else if (other_scores_5 > second_max_score && other_scores_5 < max_score) begin
                            second_max_score <= other_scores_5;
                        end
                    end
                    stage <= 4'd6;
                end
                4'd6: begin
                    if (valid_count > 6) begin
                        if (other_scores_6 > max_score) begin
                            second_max_score <= max_score;
                            max_score <= other_scores_6;
                            count_max <= 32'd1;
                        end else if (other_scores_6 == max_score) begin
                            count_max <= count_max + 32'd1;
                        end else if (other_scores_6 > second_max_score && other_scores_6 < max_score) begin
                            second_max_score <= other_scores_6;
                        end
                    end
                    stage <= 4'd7;
                end
                4'd7: begin
                    if (valid_count > 7) begin
                        if (other_scores_7 > max_score) begin
                            second_max_score <= max_score;
                            max_score <= other_scores_7;
                            count_max <= 32'd1;
                        end else if (other_scores_7 == max_score) begin
                            count_max <= count_max + 32'd1;
                        end else if (other_scores_7 > second_max_score && other_scores_7 < max_score) begin
                            second_max_score <= other_scores_7;
                        end
                    end
                    stage <= 4'd8;
                end
                default: stage <= 4'd0;
            endcase
        end else if (state == CALCULATE) begin
            if (max_score == julia_score) begin
                if (second_max_score > 0 && julia_score >= second_max_score) begin
                    guarantee_matches <= (julia_score - second_max_score) + count_max - 32'd1;
                end else begin
                    guarantee_matches <= count_max - 32'd1;
                end
            end else begin
                if (second_max_score > 0 && julia_score >= second_max_score) begin
                    guarantee_matches <= (julia_score - max_score) + (julia_score - second_max_score) + count_max - 32'd2;
                end else if (julia_score > max_score) begin
                    guarantee_matches <= julia_score - max_score;
                end else begin
                    guarantee_matches <= 32'd0;
                end
            end
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
        end else if (state == IDLE) begin
            done <= 1'b0;
        end
    end

endmodule