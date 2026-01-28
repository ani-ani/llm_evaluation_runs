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
    
    // Combinational evaluation signals
    reg [1:0] temp_op [0:N-1];
    reg signed [R_W-1:0] temp_result [0:N-1];
    reg distinct;
    integer i, j;

    always @(*) begin
        distinct = 1'b1;
        // Compute operators and results for current combo
        for (i = 0; i < N; i = i + 1) begin
            if (i < n) begin
                // Extract base-3 digits from combo_counter
                if (i == 0) temp_op[0] = combo_counter % 3;
                else if (i == 1) temp_op[1] = (combo_counter / 3) % 3;
                else if (i == 2) temp_op[2] = (combo_counter / 9) % 3;
                else if (i == 3) temp_op[3] = (combo_counter / 27) % 3;
                else temp_op[i] = 0;

                // Compute result
                case (temp_op[i])
                    2'd0: temp_result[i] = a[i] + b[i];
                    2'd1: temp_result[i] = a[i] - b[i];
                    2'd2: temp_result[i] = a[i] * b[i];
                    default: temp_result[i] = 0;
                endcase
            end else begin
                temp_op[i] = 0;
                temp_result[i] = 0;
            end
        end

        // Check distinctness among valid results
        if (n > 1) begin
            for (i = 0; i < n; i = i + 1) begin
                for (j = i+1; j < n; j = j + 1) begin
                    if (temp_result[i] == temp_result[j]) distinct = 1'b0;
                end
            end
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        done = 1'b0;
        valid = 1'b0;
        case (state)
            IDLE: if (start) next_state = SEARCH;
            SEARCH: begin
                if (distinct && combo_counter <= max_combo) next_state = FOUND;
                else if (combo_counter > max_combo) next_state = IMPOSSIBLE;
            end
            FOUND: begin
                done = 1'b1;
                valid = 1'b1;
            end
            IMPOSSIBLE: begin
                done = 1'b1;
                valid = 1'b0;
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
            for (integer k = 0; k < N; k = k + 1) begin
                op[k] <= 2'd0;
                result[k] <= 16'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        // Set max combo based on n
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
                    if (distinct && combo_counter <= max_combo) begin
                        // Load solution
                        for (integer idx = 0; idx < N; idx = idx + 1) begin
                            if (idx < n) begin
                                op[idx] <= temp_op[idx];
                                result[idx] <= temp_result[idx];
                            end else begin
                                op[idx] <= 2'd0;
                                result[idx] <= 16'd0;
                            end
                        end
                    end else if (combo_counter <= max_combo) begin
                        combo_counter <= combo_counter + 8'd1;
                    end
                end
                // FOUND and IMPOSSIBLE states hold outputs constant
            endcase
        end
    end
endmodule