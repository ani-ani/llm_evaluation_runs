module JuliaBettingStrategy(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] julia_score,
    input wire [14:0][31:0] other_scores,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SIMULATE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [7:0] match_count;
    reg [31:0] julia_reg;
    reg [14:0][31:0] others_reg;
    reg [31:0] max_other;
    reg [31:0] majority_bet;
    reg [31:0] total_bet;
    reg [31:0] majority_count;
    reg [31:0] minority_count;
    reg [31:0] bet_value;
    reg [31:0] temp_score;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            match_count <= 8'd0;
            julia_reg <= 32'd0;
            for (i = 0; i < 15; i = i + 1) begin
                others_reg[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize scores
                        julia_reg <= julia_score;
                        for (i = 0; i < 15; i = i + 1) begin
                            others_reg[i] <= other_scores[i];
                        end
                        match_count <= 8'd0;
                        state <= SIMULATE;
                    end
                end

                SIMULATE: begin
                    // Find max other score
                    max_other <= others_reg[0];
                    for (i = 1; i < 15; i = i + 1) begin
                        if (others_reg[i] > max_other) begin
                            max_other <= others_reg[i];
                        end
                    end

                    // Determine majority bet (worst case: majority loses)
                    // Count how many would bet on each outcome
                    majority_count <= 0;
                    minority_count <= 0;
                    for (i = 0; i < 15; i = i + 1) begin
                        // Simple strategy: bet on current max
                        if (others_reg[i] >= max_other) begin
                            majority_count <= majority_count + 1;
                        end else begin
                            minority_count <= minority_count + 1;
                        end
                    end

                    // Majority bet is the one with more votes
                    if (majority_count >= minority_count) begin
                        majority_bet <= max_other;
                    end else begin
                        majority_bet <= max_other + 1;
                    end

                    // Calculate total bet (simplified: each bets 1 unit)
                    total_bet <= 15;

                    // Update scores (majority loses)
                    // Julia loses (worst case)
                    julia_reg <= julia_reg - total_bet;

                    // Others: majority loses, minority wins
                    for (i = 0; i < 15; i = i + 1) begin
                        if (others_reg[i] >= max_other) begin
                            // Majority loses
                            others_reg[i] <= others_reg[i] - 1;
                        end else begin
                            // Minority wins
                            others_reg[i] <= others_reg[i] + 1;
                        end
                    end

                    // Check if Julia still leads
                    temp_score <= julia_reg;
                    for (i = 0; i < 15; i = i + 1) begin
                        if (temp_score < others_reg[i]) begin
                            temp_score <= temp_score + 1;
                        end
                    end

                    if (temp_score == julia_reg) begin
                        // Julia still leads
                        match_count <= match_count + 1;
                        if (match_count == 8'd255) begin
                            state <= FINISH;
                        end
                    end else begin
                        // Julia lost lead
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= match_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule