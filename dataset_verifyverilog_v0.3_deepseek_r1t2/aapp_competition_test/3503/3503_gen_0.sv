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
    reg distinct;
    integer i, j;

    // Temporary computation signals
    reg [1:0] temp_op [0:N-1];
    reg signed [R_W-1:0] temp_result [0:N-1];

    // Compute possible solution for current combo_counter
    always @(*) begin
        distinct = 1'b1;
        
        // Generate operations and results
        for (i = 0; i < N; i = i + 1) begin
            if (i < n) begin
                // Base-3 decomposition
                case (i)
                    0: temp_op[i] = combo_counter % 3;
                    1: temp_op[i] = (combo_counter / 3) % 3;
                    2: temp_op[i] = (combo_counter / 9) % 3;
                    3: temp_op[i] = (combo_counter / 27) % 3;
                    default: temp_op[i] = 2'd0;
                endcase

                // Compute operation
                case (temp_op[i])
                    2'd0: temp_result[i] = a[i] + b[i];
                    2'd1: temp_result[i] = a[i] - b[i];
                    2'd2: temp_result[i] = a[i] * b[i];
                    default: temp_result[i] = 0;
                endcase
            end
            else begin
                temp_op[i] = 2'd0;
                temp_result[i] = 0;
            end
        end

        // Check result distinctness
        for (i = 0; i < n; i = i + 1) begin
            for (j = i+1; j < n; j = j + 1) begin
                if (temp_result[i] == temp_result[j]) distinct = 1'b0;
            end
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        done = 1'b0;
        valid = 1'b0;
        case (state)
            IDLE: begin
                if (start) next_state = SEARCH;
            end
            SEARCH: begin
                if (combo_counter > max_combo) begin
                    next_state = IMPOSSIBLE;
                end
                else if (distinct) begin
                    next_state = FOUND;
                end
                else begin
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

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            combo_counter <= 8'd0;
            max_combo <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin
                op[i] <= 2'd0;
                result[i] <= {R_W{1'b0}};
            end
        end
        else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        case (n)
                            3'd1: max_combo <= 8'd2;
                            3'd2: max_combo <= 8'd8;
                            3'd3: max_combo <= 8'd26;
                            3'd4: max_combo <= 8'd80;
                            default: max_combo <= 8'd0;
                        endcase
                        combo_counter <= 8'd0;
                    end
                end
                SEARCH: begin
                    if (distinct) begin
                        for (i = 0; i < N; i = i + 1) begin
                            op[i] <= temp_op[i];
                            result[i] <= temp_result[i];
                        end
                    end
                    else if (combo_counter <= max_combo) begin
                        combo_counter <= combo_counter + 8'd1;
                    end
                end
                FOUND: begin
                    combo_counter <= 8'd0;
                end
                IMPOSSIBLE: begin
                    combo_counter <= 8'd0;
                end
            endcase
        end
    end
endmodule