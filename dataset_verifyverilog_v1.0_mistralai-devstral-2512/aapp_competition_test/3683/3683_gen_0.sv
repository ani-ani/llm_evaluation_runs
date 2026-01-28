module golf_ranking (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] scores [511:0][49:0],
    input wire [8:0] p,
    input wire [5:0] h,
    output reg [8:0] rank_out [511:0],
    output reg result_ready
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] START_L = 4'd1;
    localparam [3:0] COMPUTE_SUMS = 4'd2;
    localparam [3:0] COMPARE_RANKS = 4'd3;
    localparam [3:0] UPDATE_MIN = 4'd4;
    localparam [3:0] NEXT_L = 4'd5;
    localparam [3:0] DONE = 4'd6;

    reg [3:0] state;
    reg [8:0] l_counter;
    reg [8:0] player_counter;
    reg [5:0] hole_counter;
    reg [8:0] compare_counter;

    // Internal registers for sums and ranks
    reg [17:0] total_scores [511:0];
    reg [8:0] current_ranks [511:0];
    reg [8:0] min_ranks [511:0];

    // Temporary registers for computation
    reg [17:0] sum_temp;
    reg [17:0] compare_temp;
    reg [8:0] rank_temp;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            l_counter <= 9'd0;
            player_counter <= 9'd0;
            hole_counter <= 6'd0;
            compare_counter <= 9'd0;
            result_ready <= 1'b0;
            
            for (i = 0; i < 512; i = i + 1) begin
                total_scores[i] <= 18'd0;
                current_ranks[i] <= 9'd0;
                min_ranks[i] <= 9'd0;
                rank_out[i] <= 9'd0;
            end
            
            sum_temp <= 18'd0;
            compare_temp <= 18'd0;
            rank_temp <= 9'd0;
        end else begin
            case (state)
                IDLE: begin
                    result_ready <= 1'b0;
                    if (start) begin
                        state <= START_L;
                        l_counter <= 9'd1;
                    end
                end

                START_L: begin
                    if (l_counter == 9'd500) begin
                        state <= DONE;
                    end else begin
                        state <= COMPUTE_SUMS;
                        player_counter <= 9'd0;
                        hole_counter <= 6'd0;
                    end
                end

                COMPUTE_SUMS: begin
                    if (player_counter == p) begin
                        state <= COMPARE_RANKS;
                        player_counter <= 9'd0;
                        compare_counter <= 9'd0;
                    end else if (hole_counter == h) begin
                        total_scores[player_counter] <= sum_temp;
                        player_counter <= player_counter + 9'd1;
                        hole_counter <= 6'd0;
                        sum_temp <= 18'd0;
                    end else begin
                        if (scores[player_counter][hole_counter] > l_counter) begin
                            sum_temp <= sum_temp + {1'b0, l_counter};
                        end else begin
                            sum_temp <= sum_temp + scores[player_counter][hole_counter];
                        end
                        hole_counter <= hole_counter + 6'd1;
                    end
                end

                COMPARE_RANKS: begin
                    if (player_counter == p) begin
                        state <= UPDATE_MIN;
                        player_counter <= 9'd0;
                    end else if (compare_counter == p) begin
                        current_ranks[player_counter] <= rank_temp;
                        player_counter <= player_counter + 9'd1;
                        compare_counter <= 9'd0;
                        rank_temp <= 9'd0;
                    end else begin
                        if (total_scores[compare_counter] <= total_scores[player_counter]) begin
                            rank_temp <= rank_temp + 9'd1;
                        end
                        compare_counter <= compare_counter + 9'd1;
                    end
                end

                UPDATE_MIN: begin
                    if (player_counter == p) begin
                        state <= NEXT_L;
                        player_counter <= 9'd0;
                    end else begin
                        if (min_ranks[player_counter] == 9'd0 || current_ranks[player_counter] < min_ranks[player_counter]) begin
                            min_ranks[player_counter] <= current_ranks[player_counter];
                        end
                        player_counter <= player_counter + 9'd1;
                    end
                end

                NEXT_L: begin
                    l_counter <= l_counter + 9'd1;
                    state <= START_L;
                end

                DONE: begin
                    result_ready <= 1'b1;
                    for (i = 0; i < 512; i = i + 1) begin
                        rank_out[i] <= min_ranks[i];
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule