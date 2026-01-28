module ComplexToPolarConverter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] real_in,
    input wire signed [7:0] imag_in,
    output reg signed [31:0] magnitude,
    output reg signed [31:0] angle,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] SAMPLING   = 3'd1;
    localparam [2:0] SQRT_ITER  = 3'd2;
    localparam [2:0] ATAN_ITER  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers for computation
    reg signed [31:0] real_fp;
    reg signed [31:0] imag_fp;
    reg signed [31:0] real_sq;
    reg signed [31:0] imag_sq;
    reg signed [31:0] sum_sq;
    reg signed [31:0] sqrt_val;
    reg signed [31:0] sqrt_next;
    reg [7:0] sqrt_iter;
    localparam [7:0] MAX_SQRT_ITER = 8'd20;

    // ATAN2 computation registers
    reg signed [31:0] abs_real;
    reg signed [31:0] abs_imag;
    reg signed [31:0] atan_val;
    reg [1:0] quadrant;
    reg signed [31:0] angle_temp;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            magnitude <= 32'd0;
            angle <= 32'd0;
            done <= 1'b0;
            
            real_fp <= 32'd0;
            imag_fp <= 32'd0;
            real_sq <= 32'd0;
            imag_sq <= 32'd0;
            sum_sq <= 32'd0;
            sqrt_val <= 32'd0;
            sqrt_next <= 32'd0;
            sqrt_iter <= 8'd0;
            abs_real <= 32'd0;
            abs_imag <= 32'd0;
            atan_val <= 32'd0;
            quadrant <= 2'd0;
            angle_temp <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= SAMPLING;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                SAMPLING: begin
                    // Convert inputs to Q16.16
                    real_fp <= $signed({24'd0, real_in});
                    imag_fp <= $signed({24'd0, imag_in});
                    
                    // Compute squares
                    real_sq <= real_fp * real_fp;
                    imag_sq <= imag_fp * imag_fp;
                    sum_sq <= real_sq + imag_sq;
                    
                    // Initialize sqrt
                    if (sum_sq == 32'd0) begin
                        sqrt_val <= 32'd0;
                        sqrt_iter <= MAX_SQRT_ITER;
                    end else begin
                        sqrt_val <= sum_sq;
                        sqrt_iter <= 8'd0;
                    end
                    
                    // Determine quadrant
                    abs_real <= (real_fp[31]) ? -real_fp : real_fp;
                    abs_imag <= (imag_fp[31]) ? -imag_fp : imag_fp;
                    
                    if (real_fp[31] && imag_fp[31]) begin
                        quadrant <= 2'd2; // Quadrant III
                    end else if (real_fp[31]) begin
                        quadrant <= 2'd3; // Quadrant II
                    end else if (imag_fp[31]) begin
                        quadrant <= 2'd4; // Quadrant IV
                    end else begin
                        quadrant <= 2'd1; // Quadrant I
                    end
                    
                    next_state <= SQRT_ITER;
                end
                
                SQRT_ITER: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (sqrt_iter < MAX_SQRT_ITER) begin
                        // Babylonian method: x_{n+1} = 0.5 * (x_n + S/x_n)
                        if (sqrt_val != 32'd0) begin
                            sqrt_next <= (sqrt_val + (sum_sq / sqrt_val)) >> 1;
                        end else begin
                            sqrt_next <= sqrt_val;
                        end
                        
                        sqrt_val <= sqrt_next;
                        sqrt_iter <= sqrt_iter + 8'd1;
                        next_state <= SQRT_ITER;
                    end else begin
                        magnitude <= sqrt_val;
                        next_state <= ATAN_ITER;
                    end
                end
                
                ATAN_ITER: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // ATAN2 approximation using polynomial
                    // For simplicity, use a basic approximation
                    // angle = (imag / real) for |real| > |imag|
                    // angle = (π/2 - real / imag) for |imag| > |real|
                    
                    if (abs_real > abs_imag) begin
                        // Use imag/real approximation
                        if (abs_real != 32'd0) begin
                            angle_temp <= (abs_imag * 32'd10430) / abs_real; // Scale by π/2
                        end else begin
                            angle_temp <= 32'd0;
                        end
                    end else begin
                        // Use π/2 - real/imag approximation
                        if (abs_imag != 32'd0) begin
                            angle_temp <= 32'd3243F - (abs_real * 32'd10430) / abs_imag;
                        end else begin
                            angle_temp <= 32'd3243F;
                        end
                    end
                    
                    // Adjust for quadrant
                    case (quadrant)
                        2'd1: atan_val <= angle_temp; // Quadrant I
                        2'd2: atan_val <= 32'd3243F + angle_temp; // Quadrant II
                        2'd3: atan_val <= -32'd3243F + angle_temp; // Quadrant III
                        2'd4: atan_val <= -angle_temp; // Quadrant IV
                        default: atan_val <= 32'd0;
                    endcase
                    
                    angle <= atan_val;
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule