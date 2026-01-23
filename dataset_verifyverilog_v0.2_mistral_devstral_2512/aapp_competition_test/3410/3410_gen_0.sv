module quadrilateral_game_score (
    input clk,
    input rst_n,
    input start,
    input signed [11:0] x_i [0:7],
    input signed [11:0] y_i [0:7],
    output reg [31:0] total_score,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] LOAD_POINTS = 2'b01;
    localparam [1:0] CALCULATE_LOOP = 2'b10;
    localparam [1:0] DONE = 2'b11;

    reg [1:0] state = IDLE;
    reg [31:0] score_acc = 0;

    // Counters for combinations
    reg [2:0] i = 0, j = 0, k = 0, l = 0;
    reg [31:0] cross_sum = 0;
    reg [31:0] area_2x = 0;

    // Modulo constant
    localparam MOD = 1000003;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_score <= 0;
            done <= 0;
            score_acc <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            l <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_POINTS;
                        done <= 0;
                        score_acc <= 0;
                        i <= 0;
                        j <= 0;
                        k <= 0;
                        l <= 0;
                    end
                end

                LOAD_POINTS: begin
                    state <= CALCULATE_LOOP;
                end

                CALCULATE_LOOP: begin
                    // Generate next combination (i,j,k,l) where i<j<k<l
                    if (l == 7) begin
                        if (k == 6) begin
                            if (j == 5) begin
                                if (i == 4) begin
                                    state <= DONE;
                                end else begin
                                    i <= i + 1;
                                    j <= i + 1;
                                    k <= j + 1;
                                    l <= k + 1;
                                end
                            end else begin
                                j <= j + 1;
                                k <= j + 1;
                                l <= k + 1;
                            end
                        end else begin
                            k <= k + 1;
                            l <= k + 1;
                        end
                    end else begin
                        l <= l + 1;
                    end

                    // Compute 2*Area for current combination (i,j,k,l)
                    cross_sum = (x_i[i] * y_i[j] - x_i[j] * y_i[i]) +
                                (x_i[j] * y_i[k] - x_i[k] * y_i[j]) +
                                (x_i[k] * y_i[l] - x_i[l] * y_i[k]) +
                                (x_i[l] * y_i[i] - x_i[i] * y_i[l]);

                    // Absolute value and modulo
                    area_2x = (cross_sum < 0) ? -cross_sum : cross_sum;
                    score_acc <= (score_acc + area_2x) % MOD;
                end

                DONE: begin
                    total_score <= score_acc;
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule