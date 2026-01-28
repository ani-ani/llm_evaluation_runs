module crate_rearrangement #(
    parameter N = 8,
    parameter HEIGHT_BITS = 8,
    parameter ACTION_BITS = 16,
    parameter K_MAX = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [HEIGHT_BITS-1:0] stacks [0:N-1],
    output reg [ACTION_BITS-1:0] min_actions,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_TOTAL = 3'd1;
    localparam [2:0] TRY_K = 3'd2;
    localparam [2:0] CALCULATE_MOVES = 3'd3;
    localparam [2:0] UPDATE_MIN = 3'd4;
    localparam [2:0] FINISHED = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    reg [31:0] total;
    reg [31:0] current_total;
    reg [7:0] k;
    reg [7:0] m;
    reg [31:0] target;
    reg [31:0] moves;
    reg [31:0] prefix_sum;
    reg [31:0] sum_excess;
    reg [31:0] min_moves;
    reg [4:0] index;
    reg [31:0] diff;

    always @(*) begin
        case (state)
            IDLE: next_state = start ? COMPUTE_TOTAL : IDLE;
            COMPUTE_TOTAL: next_state = (index == N) ? TRY_K : COMPUTE_TOTAL;
            TRY_K: begin
                if (k > K_MAX)
                    next_state = FINISHED;
                else if (total % (N + k) == 0)
                    next_state = CALCULATE_MOVES;
                else
                    next_state = TRY_K;
            end
            CALCULATE_MOVES: next_state = (index == N + k) ? UPDATE_MIN : CALCULATE_MOVES;
            UPDATE_MIN: next_state = TRY_K;
            FINISHED: next_state = FINISHED;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total <= 0;
            current_total <= 0;
            k <= 0;
            m <= 0;
            target <= 0;
            moves <= 0;
            prefix_sum <= 0;
            sum_excess <= 0;
            min_moves <= {ACTION_BITS{1'b1}};
            index <= 0;
            diff <= 0;
            done <= 0;
            min_actions <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    min_moves <= {ACTION_BITS{1'b1}};
                end

                COMPUTE_TOTAL: begin
                    if (index < N) begin
                        current_total <= current_total + stacks[index];
                        index <= index + 1;
                    end else begin
                        total <= current_total;
                        current_total <= 0;
                        index <= 0;
                        k <= 0;
                    end
                end

                TRY_K: begin
                    if (k <= K_MAX) begin
                        if (total % (N + k) == 0) begin
                            m <= N + k;
                            target <= total / (N + k);
                            index <= 0;
                            prefix_sum <= 0;
                            sum_excess <= 0;
                            moves <= 0;
                        end else begin
                            k <= k + 1;
                        end
                    end else begin
                        min_actions <= min_moves;
                        done <= 1;
                    end
                end

                CALCULATE_MOVES: begin
                    if (index < m) begin
                        if (index < N) begin
                            diff <= stacks[index] - target;
                        end else begin
                            diff <= 0 - target;
                        end

                        prefix_sum <= prefix_sum + diff;

                        if (diff > 0) begin
                            sum_excess <= sum_excess + diff;
                        end

                        moves <= moves + 2 * (diff > 0 ? diff : 0) + ((prefix_sum + diff) > 0 ? (prefix_sum + diff) : -(prefix_sum + diff));
                        index <= index + 1;
                    end else begin
                        moves <= moves;
                    end
                end

                UPDATE_MIN: begin
                    if (moves < min_moves) begin
                        min_moves <= moves;
                    end
                    k <= k + 1;
                end

                FINISHED: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule