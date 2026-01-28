module crazy_town_min_steps (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] x1, y1, x2, y2,
    input wire signed [31:0] line_a, line_b, line_c,
    input wire line_valid,
    input wire line_end,
    output reg [8:0] step_count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESS    = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;

    // Internal signals
    reg [8:0] count_reg;
    reg done_reg;

    // 64-bit accumulators for intermediate calculations
    wire signed [63:0] val1_64;
    wire signed [63:0] val2_64;

    assign val1_64 = $signed(line_a) * $signed(x1) + $signed(line_b) * $signed(y1) + $signed(line_c);
    assign val2_64 = $signed(line_a) * $signed(x2) + $signed(line_b) * $signed(y2) + $signed(line_c);

    // Sign detection
    wire signs_differ;
    assign signs_differ = (val1_64[63] != val2_64[63]) && (val1_64 != 64'd0) && (val2_64 != 64'd0);

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count_reg <= 9'd0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    count_reg = 9'd0;
                    done_reg = 1'b0;
                end
            end

            PROCESS: begin
                if (line_valid) begin
                    if (signs_differ) begin
                        count_reg = count_reg + 9'd1;
                    end
                    if (line_end) begin
                        next_state = DONE_STATE;
                    end
                end
            end

            DONE_STATE: begin
                done_reg = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_count <= 9'd0;
            done <= 1'b0;
        end else begin
            step_count <= count_reg;
            done <= done_reg;
        end
    end

endmodule