module compute_max_colors (
    input clk,
    input rst_n,
    input start,
    input [15:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_N1 = 3'd1;
    localparam [2:0] FIND_DIVISOR = 3'd2;
    localparam [2:0] CHECK_POWER = 3'd3;
    localparam [2:0] COMPUTE_RESULT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    reg [15:0] n_reg;
    reg [15:0] divisor;
    reg [15:0] temp_val;
    reg [7:0] d;
    reg [7:0] divisor_found;
    reg is_power;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 16'd0;
            divisor <= 16'd0;
            temp_val <= 16'd0;
            d <= 8'd0;
            divisor_found <= 8'd0;
            is_power <= 1'b0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= n_in;
                    end
                end
                CHECK_N1: begin
                    // Check if n == 1
                end
                FIND_DIVISOR: begin
                    d <= d + 8'd1;
                    if (d > 8'd255) begin
                        d <= 8'd0;
                    end
                end
                CHECK_POWER: begin
                    if (temp_val % divisor == 16'd0) begin
                        temp_val <= temp_val / divisor;
                    end else begin
                        temp_val <= 16'd0;
                    end
                end
                COMPUTE_RESULT: begin
                    // Determine result based on checks
                end
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_N1;
            end
            CHECK_N1: begin
                if (n_reg == 16'd1) next_state = FINISH;
                else next_state = FIND_DIVISOR;
            end
            FIND_DIVISOR: begin
                if (d == 8'd0) begin
                    if (divisor_found == 8'd0) next_state = FINISH;
                    else next_state = CHECK_POWER;
                end else if (d <= 8'd255) begin
                    if (n_reg % d == 16'd0 && n_reg != d && d != 8'd1) begin
                        next_state = CHECK_POWER;
                    end else begin
                        next_state = FIND_DIVISOR;
                    end
                end else begin
                    if (divisor_found == 8'd0) next_state = FINISH;
                    else next_state = CHECK_POWER;
                end
            end
            CHECK_POWER: begin
                if (temp_val == 16'd1) begin
                    next_state = COMPUTE_RESULT;
                end else if (temp_val == divisor || temp_val == 16'd0) begin
                    next_state = COMPUTE_RESULT;
                end else begin
                    if (temp_val % divisor != 16'd0) begin
                        next_state = COMPUTE_RESULT;
                    end
                end
            end
            COMPUTE_RESULT: begin
                next_state = FINISH;
            end
            FINISH: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(*) begin
        done = 1'b0;
        result = 16'd0;
        case (state)
            IDLE: begin
                done = 1'b0;
            end
            CHECK_N1: begin
                if (n_reg == 16'd1) begin
                    result = 16'd1;
                end
            end
            FIND_DIVISOR: begin
                // Intermediate state, no output
            end
            CHECK_POWER: begin
                // Checking power condition
            end
            COMPUTE_RESULT: begin
                if (divisor_found != 8'd0 && is_power) begin
                    result = divisor_found;
                end else if (divisor_found != 8'd0 && !is_power) begin
                    result = 16'd1;
                end else begin
                    result = n_reg;
                end
            end
            FINISH: begin
                done = 1'b1;
                if (n_reg == 16'd1) result = 16'd1;
                else if (divisor_found != 8'd0 && is_power) result = divisor_found;
                else if (divisor_found != 8'd0 && !is_power) result = 16'd1;
                else result = n_reg;
            end
            default: begin
                done = 1'b0;
                result = 16'd0;
            end
        endcase
    end

    // Internal control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            divisor_found <= 8'd0;
            is_power <= 1'b0;
            divisor <= 16'd0;
            temp_val <= 16'd0;
        end else begin
            if (state == IDLE && start) begin
                divisor_found <= 8'd0;
                is_power <= 1'b0;
                d <= 8'd2;
            end
            if (state == FIND_DIVISOR && d <= 8'd255) begin
                if (n_reg % d == 16'd0 && n_reg != d && d != 8'd1) begin
                    divisor_found <= d;
                    divisor <= d;
                    temp_val <= n_reg;
                end
            end
            if (state == CHECK_POWER) begin
                if (temp_val % divisor == 16'd0) begin
                    temp_val <= temp_val / divisor;
                    if (temp_val / divisor == 16'd1) begin
                        is_power <= 1'b1;
                    end
                end else begin
                    if (temp_val != divisor && temp_val != 16'd1) begin
                        is_power <= 1'b0;
                    end
                end
            end
        end
    end

endmodule