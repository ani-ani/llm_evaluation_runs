module betting_guarantee (
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
localparam [2:0] IDLE = 3'd0;
localparam [2:0] FIND_MAX = 3'd1;
localparam [2:0] FIND_SECOND_MAX = 3'd2;
localparam [2:0] CALCULATE = 3'd3;
localparam [2:0] FINISH = 3'd4;

// Internal registers
reg [2:0] state;
reg [2:0] stage;
reg [31:0] max_score;
reg [31:0] second_max_score;
reg [31:0] count_max;
reg [7:0] cycle_count;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        stage <= 3'd0;
        max_score <= 32'd0;
        second_max_score <= 32'd0;
        count_max <= 32'd0;
        guarantee_matches <= 32'd0;
        done <= 1'b0;
        cycle_count <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                stage <= 3'd0;
                if (start) begin
                    state <= FIND_MAX;
                    max_score <= 32'd0;
                    second_max_score <= 32'd0;
                    count_max <= 32'd0;
                end
            end

            FIND_MAX: begin
                // Initialize max_score with first valid score
                if (stage == 3'd0) begin
                    if (valid_count > 3'd0) begin
                        max_score <= other_scores_0;
                        count_max <= 32'd1;
                    end else begin
                        max_score <= 32'd0;
                        count_max <= 32'd0;
                    end
                    stage <= 3'd1;
                end
                // Process remaining scores to find max
                else if (stage == 3'd1) begin
                    if (valid_count > 3'd1 && other_scores_1 > max_score) begin
                        max_score <= other_scores_1;
                        count_max <= 32'd1;
                    end else if (valid_count > 3'd1 && other_scores_1 == max_score) begin
                        count_max <= count_max + 32'd1;
                    end
                    stage <= 3'd2;
                end
                else if (stage == 3'd2) begin
                    if (valid_count > 3'd2 && other_scores_2 > max_score) begin
                        max_score <= other_scores_2;
                        count_max <= 32'd1;
                    end else if (valid_count > 3'd2 && other_scores_2 == max_score) begin
                        count_max <= count_max + 32'd1;
                    end
                    stage <= 3'd3;
                end
                else if (stage == 3'd3) begin
                    if (valid_count > 3'd3 && other_scores_3 > max_score) begin
                        max_score <= other_scores_3;
                        count_max <= 32'd1;
                    end else if (valid_count > 3'd3 && other_scores_3 == max_score) begin
                        count_max <= count_max + 32'd1;
                    end
                    stage <= 3'd4;
                end
                else if (stage == 3'd4) begin
                    if (valid_count > 3'd4 && other_scores_4 > max_score) begin
                        max_score <= other_scores_4;
                        count_max <= 32'd1;
                    end else if (valid_count > 3'd4 && other_scores_4 == max_score) begin
                        count_max <= count_max + 32'd1;
                    end
                    stage <= 3'd5;
                end
                else if (stage == 3'd5) begin
                    if (valid_count > 3'd5 && other_scores_5 > max_score) begin
                        max_score <= other_scores_5;
                        count_max <= 32'd1;
                    end else if (valid_count > 3'd5 && other_scores_5 == max_score) begin
                        count_max <= count_max + 32'd1;
                    end
                    stage <= 3'd6;
                end
                else if (stage == 3'd6) begin
                    if (valid_count > 3'd6 && other_scores_6 > max_score) begin
                        max_score <= other_scores_6;
                        count_max <= 32'd1;
                    end else if (valid_count > 3'd6 && other_scores_6 == max_score) begin
                        count_max <= count_max + 32'd1;
                    end
                    stage <= 3'd7;
                end
                else if (stage == 3'd7) begin
                    if (valid_count > 3'd7 && other_scores_7 > max_score) begin
                        max_score <= other_scores_7;
                        count_max <= 32'd1;
                    end else if (valid_count > 3'd7 && other_scores_7 == max_score) begin
                        count_max <= count_max + 32'd1;
                    end
                    stage <= 3'd0;
                    state <= FIND_SECOND_MAX;
                end
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= 8'd100) begin
                    state <= FINISH;
                end
            end

            FIND_SECOND_MAX: begin
                // Find second max (max score not equal to max_score)
                if (stage == 3'd0) begin
                    second_max_score <= 32'd0;
                    if (valid_count > 3'd0 && other_scores_0 != max_score) begin
                        second_max_score <= other_scores_0;
                    end
                    stage <= 3'd1;
                end
                else if (stage == 3'd1) begin
                    if (valid_count > 3'd1 && other_scores_1 != max_score && other_scores_1 > second_max_score) begin
                        second_max_score <= other_scores_1;
                    end
                    stage <= 3'd2;
                end
                else if (stage == 3'd2) begin
                    if (valid_count > 3'd2 && other_scores_2 != max_score && other_scores_2 > second_max_score) begin
                        second_max_score <= other_scores_2;
                    end
                    stage <= 3'd3;
                end
                else if (stage == 3'd3) begin
                    if (valid_count > 3'd3 && other_scores_3 != max_score && other_scores_3 > second_max_score) begin
                        second_max_score <= other_scores_3;
                    end
                    stage <= 3'd4;
                end
                else if (stage == 3'd4) begin
                    if (valid_count > 3'd4 && other_scores_4 != max_score && other_scores_4 > second_max_score) begin
                        second_max_score <= other_scores_4;
                    end
                    stage <= 3'd5;
                end
                else if (stage == 3'd5) begin
                    if (valid_count > 3'd5 && other_scores_5 != max_score && other_scores_5 > second_max_score) begin
                        second_max_score <= other_scores_5;
                    end
                    stage <= 3'd6;
                end
                else if (stage == 3'd6) begin
                    if (valid_count > 3'd6 && other_scores_6 != max_score && other_scores_6 > second_max_score) begin
                        second_max_score <= other_scores_6;
                    end
                    stage <= 3'd7;
                end
                else if (stage == 3'd7) begin
                    if (valid_count > 3'd7 && other_scores_7 != max_score && other_scores_7 > second_max_score) begin
                        second_max_score <= other_scores_7;
                    end
                    stage <= 3'd0;
                    state <= CALCULATE;
                end
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= 8'd100) begin
                    state <= FINISH;
                end
            end

            CALCULATE: begin
                // Calculate guarantee matches
                if (julia_score == max_score) begin
                    // Julia has max score
                    if (second_max_score > 32'd0 && julia_score >= second_max_score) begin
                        guarantee_matches <= (julia_score - second_max_score) + count_max - 32'd1;
                    end else begin
                        guarantee_matches <= count_max - 32'd1;
                    end
                end else begin
                    // Julia does not have max score
                    if (julia_score > max_score) begin
                        if (second_max_score > 32'd0 && julia_score >= second_max_score) begin
                            guarantee_matches <= (julia_score - max_score) + (julia_score - second_max_score) + count_max - 32'd2;
                        end else begin
                            guarantee_matches <= julia_score - max_score;
                        end
                    end else begin
                        guarantee_matches <= 32'd0;
                    end
                end
                state <= FINISH;
                cycle_count <= cycle_count + 8'd1;
            end

            FINISH: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule