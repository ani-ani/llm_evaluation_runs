module multiple_to_single(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] input_integers [0:7],
    input wire [2:0] len,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] PROCESS = 2'd2;
    localparam [1:0] FINISH  = 2'd3;

    reg [1:0] state, next_state;
    reg [2:0] idx;
    reg signed [31:0] accumulator;
    reg signed [7:0] current_val;
    reg [31:0] multiplier;
    reg sign;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Power of 10 lookup (10^1, 10^2)
    wire [31:0] pow10_1 = 32'd10;
    wire [31:0] pow10_2 = 32'd100;

    // Determine number of digits (1 or 2)
    wire num_digits;
    assign num_digits = (current_val < 10 && current_val >= 0) || (current_val > -10 && current_val < 0) ? 1 : 2;

    // Multiplier selection
    always @(*) begin
        if (num_digits == 1) begin
            multiplier = pow10_1;
        end else begin
            multiplier = pow10_2;
        end
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            LOAD: begin
                next_state = PROCESS;
            end
            PROCESS: begin
                if (idx == len - 1) begin
                    next_state = FINISH;
                end else begin
                    next_state = PROCESS;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            idx <= 3'd0;
            accumulator <= 32'd0;
            current_val <= 8'd0;
            sign <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                LOAD: begin
                    idx <= 3'd0;
                    accumulator <= 32'd0;
                    current_val <= input_integers[0];
                    sign <= (current_val < 0);
                    if (sign) begin
                        current_val <= -current_val;
                    end
                    accumulator <= current_val;
                end
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    idx <= idx + 3'd1;
                    current_val <= input_integers[idx];
                    if (current_val < 0) begin
                        current_val <= -current_val;
                    end
                    accumulator <= accumulator * multiplier + current_val;
                end
                FINISH: begin
                    if (sign) begin
                        result <= -accumulator;
                    end else begin
                        result <= accumulator;
                    end
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule