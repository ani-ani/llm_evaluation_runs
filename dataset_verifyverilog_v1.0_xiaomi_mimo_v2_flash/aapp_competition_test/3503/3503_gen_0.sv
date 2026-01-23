module ExamProblem #(
    parameter N = 4,
    parameter W = 8,
    parameter R_W = 16
)(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input signed [W-1:0] a [0:N-1],
    input signed [W-1:0] b [0:N-1],
    output reg [1:0] op [0:N-1],
    output reg signed [R_W-1:0] result [0:N-1],
    output reg done,
    output reg valid
);
    // State encoding
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCH = 2'd1;
    localparam [1:0] FOUND = 2'd2;
    localparam [1:0] IMPOSSIBLE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] combo_counter;
    reg [7:0] max_combo;
    reg found_flag;
    integer i, j;

    always @(*) begin
        next_state = state;
        done = 1'b0;
        valid = 1'b0;
        found_flag = 1'b0;

        case (state)
            IDLE: begin
                if (start) next_state = SEARCH;
            end
            SEARCH: begin
                // Check current combination
                // First, verify distinctness for first n elements
                if (n >= 2) begin
                    found_flag = 1'b1;
                    for (i = 0; i < n; i = i + 1) begin
                        for (j = i + 1; j < n; j = j + 1) begin
                            if (i < N && j < N) begin
                                if (op[i] == op[j] && result[i] == result[j]) begin
                                    found_flag = 1'b0;
                                end
                            end
                        end
                    end
                end else begin
                    found_flag = 1'b1; // Single element always distinct
                end

                if (found_flag && combo_counter <= max_combo) begin
                    next_state = FOUND;
                end else if (combo_counter > max_combo) begin
                    next_state = IMPOSSIBLE;
                end else begin
                    next_state = SEARCH;
                end
            end
            FOUND: begin
                done = 1'b1;
                valid = 1'b1;
                next_state = IDLE;
            end
            IMPOSSIBLE: begin
                done = 1'b1;
                valid = 1'b0;
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            combo_counter <= 8'd0;
            max_combo <= 8'd0;
            for (i = 0; i < N; i = i + 1) begin
                op[i] <= 2'd0;
                result[i] <= {R_W{1'b0}};
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize for search
                        combo_counter <= 8'd0;
                        case (n)
                            3'd1: max_combo <= 8'd2;
                            3'd2: max_combo <= 8'd8;
                            3'd3: max_combo <= 8'd26;
                            3'd4: max_combo <= 8'd80;
                            default: max_combo <= 8'd0;
                        endcase
                        // Initialize outputs
                        for (i = 0; i < N; i = i + 1) begin
                            op[i] <= 2'd0;
                            result[i] <= {R_W{1'b0}};
                        end
                    end
                end
                SEARCH: begin
                    if (combo_counter <= max_combo) begin
                        // Update op and result for current combination
                        for (i = 0; i < N; i = i + 1) begin
                            if (i < n) begin
                                // Decode base-3 digit from combo_counter
                                if (i == 0) begin
                                    op[i] <= combo_counter % 3;
                                end else if (i == 1) begin
                                    op[i] <= (combo_counter / 3) % 3;
                                end else if (i == 2) begin
                                    op[i] <= (combo_counter / 9) % 3;
                                end else if (i == 3) begin
                                    op[i] <= (combo_counter / 27) % 3;
                                end
                                // Compute result
                                case (op[i])
                                    2'd0: result[i] <= a[i] + b[i];
                                    2'd1: result[i] <= a[i] - b[i];
                                    2'd2: result[i] <= a[i] * b[i];
                                    default: result[i] <= {R_W{1'b0}};
                                endcase
                            end else begin
                                op[i] <= 2'd0;
                                result[i] <= {R_W{1'b0}};
                            end
                        end
                        combo_counter <= combo_counter + 8'd1;
                    end
                end
                // FOUND and IMPOSSIBLE states hold values
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule