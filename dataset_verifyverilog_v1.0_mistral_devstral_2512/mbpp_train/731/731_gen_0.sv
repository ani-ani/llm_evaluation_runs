module cone_lsa (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] radius,      // Q16.16 format
    input wire [15:0] height,      // Q16.16 format
    output reg [15:0] lsa,         // Q16.16 format
    output reg done
);

    // Parameters for Q16.16 format
    // PI approximation: 3.14159265 * 65536 = 205887
    parameter PI_FIXED = 205887;
    
    // State definitions
    parameter IDLE = 3'b000;
    parameter CALC_SQRT = 3'b001;
    parameter CALC_MULT = 3'b010;
    parameter CALC_FINAL = 3'b011;
    parameter DONE_STATE = 3'b100;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal registers for fixed-point calculations
    reg [31:0] r_sq;          // r^2 (Q32.0)
    reg [31:0] h_sq;          // h^2 (Q32.0)
    reg [31:0] sum_sq;        // r^2 + h^2 (Q32.0)
    reg [31:0] l_int;         // sqrt result (Q16.16)
    reg [47:0] r_mul_l;       // r * l (Q32.32)
    reg [47:0] pi_mul_r_l;    // pi * r * l (Q48.16)
    
    // CORDIC sqrt signals
    reg [31:0] sqrt_input;
    reg sqrt_start;
    wire sqrt_done;
    wire [15:0] sqrt_result;
    
    // Counter for multi-cycle operations
    reg [5:0] counter;
    
    // Instantiate sqrt module (simplified CORDIC)
    sqrt_cordic sqrt_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(sqrt_start),
        .number(sqrt_input),
        .result(sqrt_result),
        .done(sqrt_done)
    );
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CALC_SQRT;
            end
            CALC_SQRT: begin
                if (sqrt_done) next_state = CALC_MULT;
            end
            CALC_MULT: begin
                if (counter == 30) next_state = CALC_FINAL;
            end
            CALC_FINAL: begin
                if (counter == 50) next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            lsa <= 0;
            sqrt_start <= 0;
            counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Calculate r^2 and h^2 (shifted to integer)
                        r_sq <= radius * radius;  // Q32.0
                        h_sq <= height * height;  // Q32.0
                        sqrt_start <= 1;
                    end
                end
                
                CALC_SQRT: begin
                    sqrt_start <= 0;
                    if (sqrt_done) begin
                        l_int <= {sqrt_result, 16'h0};  // Convert to Q16.16
                        counter <= 0;
                    end
                end
                
                CALC_MULT: begin
                    counter <= counter + 1;
                    if (counter == 0) begin
                        sum_sq <= r_sq + h_sq;
                    end else if (counter == 1) begin
                        // Calculate r * l (Q16.16 * Q16.16 = Q32.32)
                        r_mul_l <= radius * l_int;
                    end
                end
                
                CALC_FINAL: begin
                    counter <= counter + 1;
                    if (counter == 0) begin
                        // Multiply by PI
                        // r_mul_l is Q32.32, PI is Q0.16
                        // Result needs to be Q16.16
                        pi_mul_r_l <= r_mul_l * PI_FIXED;
                    end else if (counter == 30) begin
                        // Shift right by 16 to get Q16.16
                        lsa <= pi_mul_r_l[47:16];
                    end
                end
                
                DONE_STATE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule

// Simplified CORDIC Square Root Module
module sqrt_cordic (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] number,
    output reg [15:0] result,
    output reg done
);
    
    reg [31:0] guess;
    reg [31:0] x, y, z;
    reg [31:0] x_new, y_new;
    reg [5:0] iter;
    reg active;
    
    // Precomputed shift values for CORDIC
    wire [31:0] shift_val;
    assign shift_val = 32'h80000000 >> iter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            active <= 0;
            result <= 0;
            iter <= 0;
        end else begin
            if (start && !active) begin
                active <= 1;
                iter <= 0;
                done <= 0;
                
                // Initialize for sqrt: x = number, y = 0, z = 0
                x <= number;
                y <= 0;
                z <= 0;
            end else if (active) begin
                if (iter < 16) begin
                    // CORDIC iteration
                    if (z < x) begin
                        x_new = x - shift_val;
                        y_new = y + shift_val;
                    end else begin
                        x_new = x + shift_val;
                        y_new = y - shift_val;
                    end
                    x <= x_new;
                    y <= y_new;
                    z <= z + 1;
                    iter <= iter + 1;
                end else begin
                    // Converged
                    result <= y[31:16];
                    done <= 1;
                    active <= 0;
                end
            end else begin
                done <= 0;
            end
        end
    end
endmodule