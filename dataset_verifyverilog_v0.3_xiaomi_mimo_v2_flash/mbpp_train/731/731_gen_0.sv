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
    localparam [31:0] PI_FIXED = 32'd205887;
    localparam [5:0] MAX_ITER = 6'd16;
    localparam [5:0] MAX_MULT_CYCLES = 6'd30;
    localparam [5:0] MAX_FINAL_CYCLES = 6'd50;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_SQRT = 3'd1;
    localparam [2:0] CALC_MULT = 3'd2;
    localparam [2:0] CALC_FINAL = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal registers for fixed-point calculations
    reg [31:0] r_sq;          // r^2 (Q32.0)
    reg [31:0] h_sq;          // h^2 (Q32.0)
    reg [31:0] sum_sq;        // r^2 + h^2 (Q32.0)
    reg [31:0] l_int;         // sqrt result (Q16.16)
    reg [47:0] r_mul_l;       // r * l (Q32.32)
    reg [47:0] pi_mul_r_l;    // pi * r * l (Q48.16)
    reg [31:0] sqrt_input;
    reg sqrt_start;
    reg [5:0] counter;
    reg [5:0] iter;
    reg active;
    
    // CORDIC internal signals
    reg [31:0] guess;
    reg [31:0] x, y, z;
    reg [31:0] x_new, y_new;
    wire [31:0] shift_val;
    assign shift_val = 32'h80000000 >> iter;
    wire sqrt_done;
    assign sqrt_done = (iter >= MAX_ITER) && active;
    wire [15:0] sqrt_result;
    assign sqrt_result = y[31:16];
    
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
                if (counter >= MAX_MULT_CYCLES) next_state = CALC_FINAL;
            end
            CALC_FINAL: begin
                if (counter >= MAX_FINAL_CYCLES) next_state = DONE_STATE;
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
            done <= 1'b0;
            lsa <= 16'd0;
            sqrt_start <= 1'b0;
            counter <= 6'd0;
            iter <= 6'd0;
            active <= 1'b0;
            r_sq <= 32'd0;
            h_sq <= 32'd0;
            sum_sq <= 32'd0;
            l_int <= 32'd0;
            r_mul_l <= 48'd0;
            pi_mul_r_l <= 48'd0;
            x <= 32'd0;
            y <= 32'd0;
            z <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    sqrt_start <= 1'b0;
                    counter <= 6'd0;
                    iter <= 6'd0;
                    active <= 1'b0;
                    if (start) begin
                        // Calculate r^2 and h^2 (shifted to integer)
                        r_sq <= radius * radius;  // Q32.0
                        h_sq <= height * height;  // Q32.0
                        sqrt_start <= 1'b1;
                    end
                end
                
                CALC_SQRT: begin
                    sqrt_start <= 1'b0;
                    if (active) begin
                        if (iter < MAX_ITER) begin
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
                        end
                    end else begin
                        // Start CORDIC
                        active <= 1'b1;
                        iter <= 6'd0;
                        x <= sum_sq;
                        y <= 32'd0;
                        z <= 32'd0;
                    end
                    if (sqrt_done) begin
                        l_int <= {sqrt_result, 16'h0};  // Convert to Q16.16
                        counter <= 6'd0;
                        active <= 1'b0;
                    end
                end
                
                CALC_MULT: begin
                    counter <= counter + 1;
                    case (counter)
                        6'd0: begin
                            sum_sq <= r_sq + h_sq;
                        end
                        6'd1: begin
                            // Calculate r * l (Q16.16 * Q16.16 = Q32.32)
                            r_mul_l <= radius * l_int;
                        end
                        default: begin
                            // Continue counting
                        end
                    endcase
                end
                
                CALC_FINAL: begin
                    counter <= counter + 1;
                    case (counter)
                        6'd0: begin
                            // Multiply by PI
                            // r_mul_l is Q32.32, PI is Q0.16
                            // Result needs to be Q16.16
                            pi_mul_r_l <= r_mul_l * PI_FIXED;
                        end
                        6'd30: begin
                            // Shift right by 16 to get Q16.16
                            lsa <= pi_mul_r_l[47:16];
                        end
                        default: begin
                            // Continue counting
                        end
                    endcase
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    done <= 1'b0;
                    lsa <= 16'd0;
                end
            endcase
        end
    end

endmodule