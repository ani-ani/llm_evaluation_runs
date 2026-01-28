module DiophantineSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] pt,
    input wire signed [31:0] p1,
    input wire signed [31:0] p2,
    output reg done,
    output reg result_valid,
    output reg [15:0] num_pitas,
    output reg [15:0] num_pizzas
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Internal registers
    reg [15:0] x_reg, y_reg;
    reg [31:0] pt_scaled, p1_scaled, p2_scaled;
    reg [31:0] rem_scaled;
    reg [15:0] max_x;
    reg [15:0] x_counter;
    reg [3:0] solution_count;
    reg [9:0] cycle_counter;
    localparam [9:0] MAX_CYCLES = 10'd1000;
    localparam [3:0] MAX_SOLUTIONS = 4'd16;

    // Convert Q16.16 to integer (scale by 2^16)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pt_scaled <= 32'd0;
            p1_scaled <= 32'd0;
            p2_scaled <= 32'd0;
        end else begin
            pt_scaled <= pt << 16;
            p1_scaled <= p1 << 16;
            p2_scaled <= p2 << 16;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            done <= 1'b0;
            x_counter <= 16'd0;
            solution_count <= 4'd0;
            cycle_counter <= 10'd0;
            num_pitas <= 16'd0;
            num_pizzas <= 16'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                if (cycle_counter >= MAX_CYCLES || x_counter > max_x) begin
                    if (solution_count == 4'd0) begin
                        next_state = DONE_STATE;
                    end else begin
                        next_state = OUTPUT;
                    end
                end
            end

            OUTPUT: begin
                if (solution_count >= MAX_SOLUTIONS) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_x <= 16'd0;
            x_counter <= 16'd0;
            rem_scaled <= 32'd0;
            x_reg <= 16'd0;
            y_reg <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    cycle_counter <= 10'd0;
                    solution_count <= 4'd0;
                    x_counter <= 16'd0;
                    
                    // Calculate max_x = floor(pt / p1)
                    if (p1_scaled != 32'd0) begin
                        if (p1_scaled > 32'd0) begin
                            max_x <= pt_scaled[31:16] / p1_scaled[31:16];
                        end else begin
                            max_x <= 16'd0;
                        end
                    end else begin
                        max_x <= 16'd0;
                    end
                end

                COMPUTE: begin
                    cycle_counter <= cycle_counter + 10'd1;
                    
                    // Calculate rem = pt - x * p1
                    rem_scaled <= pt_scaled - ($signed(x_counter) * p1_scaled);
                    
                    // Check if rem >= 0 and divisible by p2
                    if (rem_scaled >= 32'd0 && p2_scaled != 32'd0) begin
                        if (rem_scaled % p2_scaled == 32'd0) begin
                            // Valid solution found
                            x_reg <= x_counter;
                            y_reg <= rem_scaled / p2_scaled;
                            
                            // Store solution
                            if (solution_count < MAX_SOLUTIONS) begin
                                solution_count <= solution_count + 4'd1;
                            end
                        end
                    end
                    
                    // Increment x_counter
                    if (x_counter < max_x) begin
                        x_counter <= x_counter + 16'd1;
                    end
                end

                OUTPUT: begin
                    result_valid <= 1'b1;
                    num_pitas <= x_reg;
                    num_pizzas <= y_reg;
                    
                    // Move to next solution
                    if (solution_count < MAX_SOLUTIONS) begin
                        // Increment to next solution (simplified - in real design would need storage)
                        solution_count <= solution_count + 4'd1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result_valid <= 1'b0;
                end

                default: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule