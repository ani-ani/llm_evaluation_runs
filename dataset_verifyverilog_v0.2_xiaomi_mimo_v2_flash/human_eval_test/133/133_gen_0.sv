module sum_squares (
    input clk,
    input rst_n,
    input start,
    input [4:0] num_elements,
    input [31:0] input_list [0:7],
    output reg [31:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam CEIL = 3'b010;
    localparam SQUARE = 3'b011;
    localparam ACCUM = 3'b100;
    localparam DONE = 3'b101;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] element_cnt;       // Counter for current element index (max 8)
    reg [31:0] accumulator;      // Accumulator in Q16.16
    reg [31:0] current_val;      // Registered input value
    reg [31:0] ceiled_int;       // Ceiled integer value (signed)
    reg [31:0] squared_val;      // Squared value in Q16.16
    reg [3:0] cycle_cnt;         // Latency counter for SQRT/MULT simulation

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? LOAD : IDLE;
            LOAD:       next_state = CEIL;
            CEIL:       next_state = SQUARE;
            SQUARE:     next_state = (cycle_cnt == 3) ? ACCUM : SQUARE; // 3 cycles latency for square
            ACCUM:      next_state = (element_cnt == num_elements - 1) ? DONE : LOAD;
            DONE:       next_state = DONE;
            default:    next_state = IDLE;
        endcase
    end

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            element_cnt <= 0;
            accumulator <= 0;
            result <= 0;
            done <= 0;
            cycle_cnt <= 0;
        end else begin
            state <= next_state;

            // Default control signals
            done <= 0;
            
            // Cycle Counter for Squaring Latency
            if (state == SQUARE) begin
                cycle_cnt <= cycle_cnt + 1;
            end else begin
                cycle_cnt <= 0;
            end

            case (state)
                IDLE: begin
                    if (start) begin
                        accumulator <= 0;
                        element_cnt <= 0;
                    end
                end

                LOAD: begin
                    current_val <= input_list[element_cnt];
                end

                CEIL: begin
                    // Ceiling Logic:
                    // If value >= 0: 
                    //   If fractional > 0, int_part + 1. Else int_part.
                    // If value < 0:
                    //   Ceiling is toward zero. 
                    //   If fractional == 0, int_part. Else int_part (since it rounds up to 0).
                    
                    if (current_val[31]) begin
                        // Negative number (MSB is 1)
                        if (current_val[15:0] == 16'h0000) begin
                            // No fractional part (e.g., -2.0)
                            ceiled_int <= { {1'b1}, current_val[30:16] }; // Sign extend 17 bits
                        end else begin
                            // Fractional part > 0 (e.g., -2.4)
                            // Ceiling toward zero means it becomes -2 (truncated integer)
                            ceiled_int <= { {1'b1}, current_val[30:16] }; 
                        end
                    end else begin
                        // Positive number (MSB is 0)
                        if (current_val[15:0] == 16'h0000) begin
                            // No fractional part
                            ceiled_int <= { 1'b0, current_val[30:16] }; // Zero extend 17 bits
                        end else begin
                            // Fractional part > 0
                            ceiled_int <= { 1'b0, current_val[30:16] } + 1;
                        end
                    end
                end

                SQUARE: begin
                    if (cycle_cnt == 0) begin
                        // Start multiplication (behavioral for latency modeling)
                        // In real hardware, this would drive DSP/Mult block inputs
                    end else if (cycle_cnt == 3) begin
                        // Calculate squared value in Q16.16
                        // Input is 17-bit signed integer. Result is 34-bit signed.
                        // We need to shift left by 16 to convert to Q16.16.
                        // Since result is small (8^2=64), we don't overflow 32 bits after shift.
                        
                        // Verilation requires signed multiplication handling manually or via signed types.
                        // Using signed keyword ensures correct multiplication sign extension.
                        // ceiled_int is treated as signed here implicitly by the signed arithmetic.
                        // Let's explicitly cast to ensure 34-bit result logic.
                        
                        // We multiply (ceiled_int) by (ceiled_int)
                        // ceiled_int is 32 bits wide, but we only care about the lower 17 bits (value)
                        // and sign extension.
                        // Let's use temporary variables for clarity.
                        
                        // Logic:
                        // Product = (ceiled_int[16:0] * ceiled_int[16:0]) << 16
                        
                        // We assume synthesis tools handle width extension correctly.
                        // Temporary 34-bit wire logic is best done in combinational block or here.
                        // Here inside sequential block, we perform the final result assignment.
                        // The multiplication below produces 34 bits.
                        
                        // Fix: Extract specific bits to avoid implicit width issues in always block
                        // or use a helper wire defined outside. Since I must generate a single module,
                        // I will calculate the product here.
                        
                        // $signed(ceiled_int[16:0]) ensures correct sign extension during multiply
                        squared_val <= ($signed(ceiled_int[16:0]) * $signed(ceiled_int[16:0])) << 16;
                    end
                end

                ACCUM: begin
                    accumulator <= accumulator + squared_val;
                end

                DONE: begin
                    done <= 1;
                    result <= accumulator;
                end
            endcase
        end
    end

endmodule
