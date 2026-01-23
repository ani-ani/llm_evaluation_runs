module pattern_sorter #(
    parameter NUM_PATTERNS = 4,
    parameter PATTERN_LENGTH = 8,
    parameter DATA_WIDTH = 2,
    parameter SCORE_WIDTH = 8,
    parameter N_WIDTH = 20
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [N_WIDTH-1:0] n,
    input wire [DATA_WIDTH*PATTERN_LENGTH-1:0] patterns_in [0:NUM_PATTERNS-1],
    output reg done,
    output reg [DATA_WIDTH*PATTERN_LENGTH-1:0] patterns_out [0:NUM_PATTERNS-1]
);

    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] COMPUTE_PREFIX  = 3'd1;
    localparam [2:0] SUM_SCORES      = 3'd2;
    localparam [2:0] SORT_PATTERNS   = 3'd3;
    localparam [2:0] FINISH          = 3'd4;

    reg [2:0] state, next_state;
    reg [1:0] current_pattern;
    reg [2:0] current_i;
    reg [2:0] pi_array [0:7];
    reg [SCORE_WIDTH-1:0] scores [0:3];
    reg [1:0] sort_pass;
    reg [1:0] sort_index;
    reg swapped;
    reg [SCORE_WIDTH-1:0] temp_score;
    reg [DATA_WIDTH*PATTERN_LENGTH-1:0] temp_pattern;
    reg [7:0] cycle_count;

    integer i;
    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            current_pattern <= 2'd0;
            current_i <= 3'd0;
            sort_pass <= 2'd0;
            sort_index <= 2'd0;
            swapped <= 1'b0;
            temp_score <= 8'd0;
            cycle_count <= 8'd0;

            for (i=0; i < NUM_PATTERNS; i = i+1) begin
                scores[i] <= 8'd0;
                patterns_out[i] <= {(DATA_WIDTH*PATTERN_LENGTH){1'b0}};
            end

            for (j=0; j < PATTERN_LENGTH; j = j+1) begin
                pi_array[j] <= 3'd0;
            end
        end else begin
            cycle_count <= cycle_count + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_PREFIX;
                        current_pattern <= 2'd0;
                        current_i <= 3'd1;
                        pi_array[0] <= 3'd0;
                        for (i=0; i < NUM_PATTERNS; i = i +1)
                            patterns_out[i] <= patterns_in[i];
                    end
                end

                COMPUTE_PREFIX: begin
                    if (cycle_count >= 8'd100) begin
                        state <= IDLE;
                    end else begin
                        if (current_i < PATTERN_LENGTH) begin
                            // Compute pi_array[current_i]
                            reg [2:0] k;
                            k = pi_array[current_i - 1];
                            while (k > 3'd0) begin
                                if (patterns_out[current_pattern][current_i*DATA_WIDTH +: DATA_WIDTH] == patterns_out[current_pattern][k*DATA_WIDTH +: DATA_WIDTH]) begin
                                    break;
                                end else begin
                                    k = pi_array[k - 1];
                                end
                            end
                            if (patterns_out[current_pattern][current_i*DATA_WIDTH +: DATA_WIDTH] == patterns_out[current_pattern][k*DATA_WIDTH +: DATA_WIDTH] && current_i != k) begin
                                pi_array[current_i] <= k + 1;
                            end else begin
                                pi_array[current_i] <= 3'd0;
                            end
                            current_i <= current_i + 1;
                        end else begin
                            state <= SUM_SCORES;
                            current_i <= 3'd0;
                        end
                    end
                end

                SUM_SCORES: begin
                    reg [SCORE_WIDTH-1:0] sum;
                    sum = 8'd0;
                    for (j=0; j < PATTERN_LENGTH; j = j+1) begin
                        sum = sum + pi_array[j];
                    end
                    scores[current_pattern] <= sum;

                    if (current_pattern < NUM_PATTERNS - 1) begin
                        current_pattern <= current_pattern + 1;
                        current_i <= 3'd1;
                        pi_array[0] <= 3'd0;
                        state <= COMPUTE_PREFIX;
                    end else begin
                        state <= SORT_PATTERNS;
                        sort_pass <= 2'd0;
                        sort_index <= 2'd0;
                        swapped <= 1'b0;
                    end
                end

                SORT_PATTERNS: begin
                    if (sort_pass < NUM_PATTERNS - 1) begin
                        if (sort_index < NUM_PATTERNS - 1 - sort_pass) begin
                            if (scores[sort_index] > scores[sort_index + 1]) begin
                                temp_score <= scores[sort_index];
                                temp_pattern <= patterns_out[sort_index];
                                scores[sort_index] <= scores[sort_index + 1];
                                patterns_out[sort_index] <= patterns_out[sort_index + 1];
                                scores[sort_index + 1] <= temp_score;
                                patterns_out[sort_index + 1] <= temp_pattern;
                                swapped <= 1'b1;
                            end
                            sort_index <= sort_index + 1;
                        end else begin
                            if (!swapped) begin
                                state <= FINISH;
                            end else begin
                                sort_pass <= sort_pass + 1;
                                sort_index <= 2'd0;
                                swapped <= 1'b0;
                            end
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule