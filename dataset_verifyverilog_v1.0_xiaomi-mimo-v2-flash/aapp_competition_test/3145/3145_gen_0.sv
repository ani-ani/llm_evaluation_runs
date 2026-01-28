module digit_multiplier_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] X,
    input wire [15:0] A,
    input wire [15:0] B,
    input wire [9:0] allowed,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] CHECK_DIV = 3'd2;
    localparam [2:0] EXTRACT   = 3'd3;
    localparam [2:0] COUNT     = 3'd4;
    localparam [2:0] NEXT      = 3'd5;
    localparam [2:0] FINISH    = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] current_n;
    reg [15:0] temp_n;
    reg [15:0] divisor_acc;
    reg [3:0] digit;
    reg valid_number;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    localparam [15:0] MAX_ITER = 16'd65535;

    // Reset and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_n <= 16'd0;
            temp_n <= 16'd0;
            divisor_acc <= 16'd0;
            digit <= 4'd0;
            valid_number <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        result <= 16'd0;
                        current_n <= A;
                        cycle_count <= 8'd0;
                    end
                end
                INIT: begin
                    temp_n <= current_n;
                    divisor_acc <= current_n;
                    cycle_count <= cycle_count + 8'd1;
                end
                CHECK_DIV: begin
                    if (divisor_acc >= X) begin
                        divisor_acc <= divisor_acc - X;
                    end
                end
                EXTRACT: begin
                    if (temp_n == 16'd0) begin
                        digit <= 4'd0;
                    end else begin
                        digit <= temp_n[3:0];
                        temp_n <= temp_n >> 4;
                    end
                end
                COUNT: begin
                    if (digit <= 4'd9 && allowed[digit]) begin
                        valid_number <= valid_number & 1'b1;
                    end else begin
                        valid_number <= 1'b0;
                    end
                end
                NEXT: begin
                    if (valid_number && (divisor_acc == 16'd0 || divisor_acc == X)) begin
                        result <= result + 16'd1;
                    end
                    current_n <= current_n + 16'd1;
                    valid_number <= 1'b1;
                end
                FINISH: begin
                    done <= 1'b1;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: begin
                next_state = CHECK_DIV;
            end
            CHECK_DIV: begin
                if (divisor_acc < X && divisor_acc != 16'd0) begin
                    next_state = EXTRACT;
                end else if (divisor_acc == 16'd0 || divisor_acc == X) begin
                    next_state = EXTRACT;
                end else begin
                    next_state = CHECK_DIV;
                end
            end
            EXTRACT: begin
                if (temp_n == 16'd0 && digit == 4'd0) begin
                    next_state = COUNT;
                end else if (temp_n == 16'd0 && digit != 4'd0) begin
                    next_state = COUNT;
                end else begin
                    next_state = EXTRACT;
                end
            end
            COUNT: begin
                if (temp_n == 16'd0 && digit == 4'd0) begin
                    next_state = NEXT;
                end else if (temp_n == 16'd0) begin
                    next_state = NEXT;
                end else begin
                    next_state = EXTRACT;
                end
            end
            NEXT: begin
                if (current_n > B || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    next_state = INIT;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule