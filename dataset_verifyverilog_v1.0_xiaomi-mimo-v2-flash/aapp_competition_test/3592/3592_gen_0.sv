module DiophantineSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] pt,
    input wire [31:0] p1,
    input wire [31:0] p2,
    output reg done,
    output reg result_valid,
    output reg [15:0] num_pitas,
    output reg [15:0] num_pizzas
);

    // State machine definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_MAX_X = 3'd1;
    localparam [2:0] CHECK_SOLUTION = 3'd2;
    localparam [2:0] OUTPUT_PAIR = 3'd3;
    localparam [2:0] INCREMENT_X = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    localparam [2:0] ERROR = 3'd6;

    // Internal registers and wires
    reg [2:0] state, next_state;
    reg [15:0] x_counter;           // Current pitas (x)
    reg [15:0] max_x;               // Maximum x value
    reg [15:0] output_count;        // Number of outputs found
    reg [31:0] rem;                 // Remaining profit
    reg [31:0] y_val;               // Calculated y
    reg [31:0] pt_int, p1_int, p2_int; // Integer representations
    reg [31:0] x_times_p1;          // x * p1
    reg [31:0] div_result;          // Division result
    reg [31:0] rem_mod_p2;          // Remainder modulo p2
    reg div_done;                   // Division complete flag
    reg [5:0] div_count;            // Division cycle counter

    // Max iterations constants
    localparam [15:0] MAX_ITERATIONS = 16'd1000;
    localparam [15:0] MAX_OUTPUTS = 16'd16;
    localparam [5:0] DIV_CYCLES = 6'd32; // 32-bit division cycles

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_counter <= 16'd0;
            max_x <= 16'd0;
            output_count <= 16'd0;
            rem <= 32'd0;
            y_val <= 32'd0;
            x_times_p1 <= 32'd0;
            pt_int <= 32'd0;
            p1_int <= 32'd0;
            p2_int <= 32'd0;
            div_result <= 32'd0;
            rem_mod_p2 <= 32'd0;
            div_done <= 1'b0;
            div_count <= 6'd0;
            done <= 1'b0;
            result_valid <= 1'b0;
            num_pitas <= 16'd0;
            num_pizzas <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    output_count <= 16'd0;
                    x_counter <= 16'd0;
                    div_done <= 1'b0;
                    div_count <= 6'd0;
                    if (start) begin
                        // Convert Q16.16 to integer by shifting right 16 bits
                        pt_int <= {1'b0, pt[31:16]};
                        p1_int <= {1'b0, p1[31:16]};
                        p2_int <= {1'b0, p2[31:16]};
                    end
                end

                CALC_MAX_X: begin
                    // Calculate max_x = floor(pt / p1) using integer division
                    if (!div_done && p1_int != 32'd0) begin
                        if (div_count < DIV_CYCLES) begin
                            div_count <= div_count + 6'd1;
                            // Restore div_result and remainder for next iteration
                            if (div_count == 6'd0) begin
                                div_result <= 32'd0;
                                rem_mod_p2 <= pt_int;
                            end else begin
                                if (rem_mod_p2 >= p1_int) begin
                                    rem_mod_p2 <= rem_mod_p2 - p1_int;
                                    div_result <= div_result + 32'd1;
                                end
                            end
                        end else begin
                            div_done <= 1'b1;
                            max_x <= div_result[15:0];
                        end
                    end else if (p1_int == 32'd0) begin
                        // If p1 is 0, handle error or max_x appropriately
                        max_x <= 16'd0;
                    end
                end

                CHECK_SOLUTION: begin
                    div_done <= 1'b0;
                    div_count <= 6'd0;
                    // Calculate x * p1
                    x_times_p1 <= x_counter * p1_int;
                    // Calculate rem = pt - x * p1
                    rem <= pt_int - (x_counter * p1_int);
                    result_valid <= 1'b0;
                end

                OUTPUT_PAIR: begin
                    // Stream output
                    result_valid <= 1'b1;
                    num_pitas <= x_counter;
                    num_pizzas <= y_val[15:0];
                    output_count <= output_count + 16'd1;
                end

                INCREMENT_X: begin
                    result_valid <= 1'b0;
                    x_counter <= x_counter + 16'd1;
                end

                FINISH: begin
                    done <= 1'b1;
                end

                ERROR: begin
                    done <= 1'b1;
                end
            endcase
            
            // Division logic for y calculation
            if (state == CHECK_SOLUTION && !div_done && p2_int != 32'd0) begin
                if (div_count < DIV_CYCLES) begin
                    div_count <= div_count + 6'd1;
                    if (div_count == 6'd0) begin
                        div_result <= 32'd0;
                        rem_mod_p2 <= rem;
                    end else begin
                        if (rem_mod_p2 >= p2_int) begin
                            rem_mod_p2 <= rem_mod_p2 - p2_int;
                            div_result <= div_result + 32'd1;
                        end
                    end
                end else begin
                    div_done <= 1'b1;
                    if (rem_mod_p2 == 32'd0 && rem >= 32'd0) begin
                        y_val <= div_result;
                        next_state <= OUTPUT_PAIR;
                    end else begin
                        next_state <= INCREMENT_X;
                    end
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (p1_int == 32'd0 || p2_int == 32'd0) begin
                        next_state = ERROR;
                    end else begin
                        next_state = CALC_MAX_X;
                    end
                end
            end

            CALC_MAX_X: begin
                if (div_done) begin
                    next_state = CHECK_SOLUTION;
                end
            end

            CHECK_SOLUTION: begin
                // Wait for division or check immediate conditions
                if (p2_int == 32'd0) begin
                    next_state = INCREMENT_X;
                end else if (div_done) begin
                    // This is handled in sequential logic
                end
            end

            OUTPUT_PAIR: begin
                // Move to increment after output
                next_state = INCREMENT_X;
            end

            INCREMENT_X: begin
                if (output_count >= MAX_OUTPUTS) begin
                    next_state = FINISH;
                end else if (x_counter >= max_x || x_counter >= MAX_ITERATIONS) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_SOLUTION;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            ERROR: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
        
        // Override for CHECK_SOLUTION to handle division state
        if (state == CHECK_SOLUTION && p2_int != 32'd0 && !div_done) begin
            if (div_count >= DIV_CYCLES) begin
                if (rem >= 32'd0 && rem_mod_p2 == 32'd0) begin
                    next_state = OUTPUT_PAIR;
                end else begin
                    next_state = INCREMENT_X;
                end
            end else begin
                next_state = CHECK_SOLUTION; // Stay in state for division
            end
        end
    end

endmodule