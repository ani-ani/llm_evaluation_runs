module stone_game (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_piles,
    input [7:0][3:0] piles,
    output reg winner,
    output reg valid,
    output reg done
);

    // Internal registers
    reg [3:0] state;
    reg [3:0] sort_state;
    reg [3:0] check_state;
    reg [3:0] calc_state;
    reg [3:0] done_state;
    reg [3:0] cycle_count;
    reg [3:0] i, j;
    reg [3:0] temp;
    reg [3:0] sorted_piles [0:7];
    reg [3:0] sum;
    reg [1:0] duplicate_count;
    reg [3:0] duplicate_value;
    reg [3:0] prev_value;
    reg duplicate_flag;
    reg [3:0] check_i;
    reg [3:0] check_j;

    // State definitions
    localparam IDLE = 4'd0;
    localparam SORT = 4'd1;
    localparam CHECK_INVALID = 4'd2;
    localparam CALCULATE = 4'd3;
    localparam DONE = 4'd4;

    // Reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sort_state <= 0;
            check_state <= 0;
            calc_state <= 0;
            done_state <= 0;
            cycle_count <= 0;
            i <= 0;
            j <= 0;
            temp <= 0;
            sum <= 0;
            duplicate_count <= 0;
            duplicate_value <= 0;
            prev_value <= 0;
            duplicate_flag <= 0;
            check_i <= 0;
            check_j <= 0;
            winner <= 0;
            valid <= 0;
            done <= 0;
            for (int k = 0; k < 8; k = k + 1) begin
                sorted_piles[k] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= SORT;
                        sort_state <= 0;
                        cycle_count <= 0;
                        for (int k = 0; k < 8; k = k + 1) begin
                            sorted_piles[k] <= piles[k];
                        end
                    end
                end
                SORT: begin
                    case (sort_state)
                        0: begin // Initialize
                            i <= 0;
                            j <= 0;
                            sort_state <= 1;
                        end
                        1: begin // Bubble sort pass
                            if (j < 7) begin
                                if (sorted_piles[j] > sorted_piles[j + 1]) begin
                                    temp <= sorted_piles[j];
                                    sorted_piles[j] <= sorted_piles[j + 1];
                                    sorted_piles[j + 1] <= temp;
                                end
                                j <= j + 1;
                            end else begin
                                j <= 0;
                                if (i < 6) begin
                                    i <= i + 1;
                                end else begin
                                    sort_state <= 2;
                                end
                            end
                        end
                        2: begin // Done sorting
                            state <= CHECK_INVALID;
                            check_state <= 0;
                            check_i <= 0;
                            check_j <= 0;
                            duplicate_count <= 0;
                            duplicate_value <= 0;
                            prev_value <= 0;
                            duplicate_flag <= 0;
                        end
                    endcase
                end
                CHECK_INVALID: begin
                    case (check_state)
                        0: begin // Initialize
                            check_i <= 0;
                            check_j <= 0;
                            duplicate_count <= 0;
                            duplicate_value <= 0;
                            prev_value <= 0;
                            duplicate_flag <= 0;
                            check_state <= 1;
                        end
                        1: begin // Check for duplicates
                            if (check_i < num_piles) begin
                                if (check_j < num_piles && check_j != check_i) begin
                                    if (sorted_piles[check_i] == sorted_piles[check_j] && sorted_piles[check_i] != 0) begin
                                        duplicate_count <= duplicate_count + 1;
                                        duplicate_value <= sorted_piles[check_i];
                                    end
                                    check_j <= check_j + 1;
                                end else begin
                                    check_j <= 0;
                                    check_i <= check_i + 1;
                                end
                            end else begin
                                check_state <= 2;
                            end
                        end
                        2: begin // Check duplicate conditions
                            if (duplicate_count > 1) begin
                                valid <= 0;
                                winner <= 0;
                            end else if (duplicate_value == 0) begin
                                valid <= 0;
                                winner <= 0;
                            end else begin
                                check_i <= 0;
                                check_state <= 3;
                            end
                        end
                        3: begin // Check if V-1 is present
                            if (check_i < num_piles) begin
                                if (sorted_piles[check_i] == duplicate_value - 1) begin
                                    valid <= 0;
                                    winner <= 0;
                                end
                                check_i <= check_i + 1;
                            end else begin
                                valid <= 1;
                                check_state <= 4;
                            end
                        end
                        4: begin // Proceed to calculate
                            state <= CALCULATE;
                            calc_state <= 0;
                            sum <= 0;
                            i <= 0;
                        end
                    endcase
                end
                CALCULATE: begin
                    case (calc_state)
                        0: begin // Initialize
                            sum <= 0;
                            i <= 0;
                            calc_state <= 1;
                        end
                        1: begin // Calculate sum
                            if (i < num_piles) begin
                                sum <= sum + (sorted_piles[i] - i);
                                i <= i + 1;
                            end else begin
                                calc_state <= 2;
                            end
                        end
                        2: begin // Determine winner
                            winner <= sum[0];
                            state <= DONE;
                            done_state <= 0;
                        end
                    endcase
                end
                DONE: begin
                    case (done_state)
                        0: begin
                            done <= 1;
                            done_state <= 1;
                        end
                        1: begin
                            if (!start) begin
                                state <= IDLE;
                                done <= 0;
                            end
                        end
                    endcase
                end
            endcase
        end
    end

endmodule