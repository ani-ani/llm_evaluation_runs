module PolylineMinX(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a_in,
    input wire [31:0] b_in,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] DIVIDE   = 3'd3;
    localparam [2:0] UPDATE   = 3'd4;
    localparam [2:0] NEXT_K   = 3'd5;
    localparam [2:0] FINISH   = 3'd6;
    
    reg [2:0] state, next_state;
    
    // Fixed-point conversion parameters
    localparam [31:0] ONE = 32'd65536;  // 1.0 in Q16.16
    localparam [31:0] NEG_ONE = 32'hFFFFFFFF;  // -1 encoded
    localparam [7:0] MAX_ITER = 8'd64;
    localparam [7:0] DIV_CYCLES = 8'd17;  // Max cycles for division
    
    // Registers for input values (converted to fixed-point)
    reg [31:0] a_fixed;
    reg [31:0] b_fixed;
    reg [31:0] min_x;
    reg [7:0] k;
    reg [7:0] div_counter;
    
    // Intermediate calculation registers
    reg [31:0] a_minus_b;
    reg [31:0] a_plus_b;
    reg [31:0] two_b;
    reg [63:0] k_times_2b;
    reg [31:0] numerator;
    reg [31:0] denominator;
    reg [31:0] current_x;
    reg is_valid_x1;
    reg is_valid_x2;
    
    // Division state
    reg [63:0] div_numerator;
    reg [31:0] div_denominator;
    reg [31:0] div_quotient;
    reg [31:0] div_rem;
    reg [5:0] div_bit;  // 32-bit division needs 32 cycles, but we use 17 for speed
    reg div_in_progress;
    
    // Internal signals
    wire [63:0] k_times_2b_wire;
    wire [63:0] k_times_2b_wire_2;
    wire [63:0] a_minus_b_ext;
    wire [63:0] a_plus_b_ext;
    wire [31:0] x1_candidate;
    wire [31:0] x2_candidate;
    wire [31:0] min_of_two;
    wire start_div;
    
    // Combinational signals for comparisons
    assign k_times_2b_wire = {32'd0, k} * two_b;
    assign k_times_2b_wire_2 = {32'd0, k} * two_b;
    assign a_minus_b_ext = {32'd0, a_minus_b};
    assign a_plus_b_ext = {32'd0, a_plus_b};
    
    // Division start signal
    assign start_div = div_in_progress && (div_bit < 6'd32);
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            
            LOAD: begin
                // Check special cases
                if (b_fixed > a_fixed)
                    next_state = FINISH;  // Return -1
                else if (b_fixed == a_fixed)
                    next_state = FINISH;  // Return a
                else
                    next_state = CHECK;
            end
            
            CHECK: begin
                if (k > MAX_ITER)
                    next_state = FINISH;
                else
                    next_state = DIVIDE;
            end
            
            DIVIDE: begin
                if (is_valid_x1 || is_valid_x2) begin
                    if (!div_in_progress)
                        next_state = DIVIDE;  // Wait for division to start
                    else if (div_bit >= 6'd32)  // Division complete (used 32 cycles)
                        next_state = UPDATE;
                    else
                        next_state = DIVIDE;  // Continue division
                end else begin
                    next_state = NEXT_K;
                end
            end
            
            UPDATE: begin
                next_state = NEXT_K;
            end
            
            NEXT_K: begin
                next_state = CHECK;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic and registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            a_fixed <= 32'd0;
            b_fixed <= 32'd0;
            min_x <= 32'hFFFFFFFF;
            k <= 8'd0;
            a_minus_b <= 32'd0;
            a_plus_b <= 32'd0;
            two_b <= 32'd0;
            is_valid_x1 <= 1'b0;
            is_valid_x2 <= 1'b0;
            div_in_progress <= 1'b0;
            div_bit <= 6'd0;
            div_numerator <= 64'd0;
            div_denominator <= 32'd0;
            div_quotient <= 32'd0;
            div_rem <= 32'd0;
            numerator <= 32'd0;
            denominator <= 32'd0;
            current_x <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Convert inputs to fixed-point
                        a_fixed <= a_in << 16;
                        b_fixed <= b_in << 16;
                        min_x <= 32'hFFFFFFFF;
                        k <= 8'd1;
                    end
                end
                
                LOAD: begin
                    // Prepare intermediate values
                    a_minus_b <= a_fixed - b_fixed;
                    a_plus_b <= a_fixed + b_fixed;
                    two_b <= b_fixed << 1;  // 2 * b
                    div_in_progress <= 1'b0;
                end
                
                CHECK: begin
                    // Check conditions for current k
                    k_times_2b <= {32'd0, k} * two_b;
                    
                    is_valid_x1 <= (k_times_2b_wire <= a_minus_b_ext);
                    is_valid_x2 <= (k_times_2b_wire_2 <= a_plus_b_ext);
                    
                    // Prepare division if needed
                    if (k_times_2b_wire <= a_minus_b_ext) begin
                        numerator <= a_minus_b;
                        denominator <= k_times_2b_wire[31:0];
                    end else if (k_times_2b_wire_2 <= a_plus_b_ext) begin
                        numerator <= a_plus_b;
                        denominator <= k_times_2b_wire_2[31:0];
                    end
                end
                
                DIVIDE: begin
                    if (is_valid_x1 || is_valid_x2) begin
                        if (!div_in_progress) begin
                            // Start division
                            div_in_progress <= 1'b1;
                            div_bit <= 6'd0;
                            // For Q16.16 division: numerator * ONE / denominator
                            // But we want result in Q16.16, so numerator should be shifted left
                            div_numerator <= {numerator, 16'd0};  // numerator << 16
                            div_denominator <= denominator;
                            div_quotient <= 32'd0;
                            div_rem <= 32'd0;
                        end else if (div_bit < 6'd32) begin
                            // Shift and subtract algorithm
                            div_numerator <= div_numerator << 1;
                            {div_rem, div_quotient} <= {div_rem[30:0], div_quotient[30:0], 1'b0};
                            
                            // Check if remainder >= denominator
                            if (div_rem >= div_denominator) begin
                                div_rem <= div_rem - div_denominator;
                                div_quotient[0] <= 1'b1;
                            end
                            
                            div_bit <= div_bit + 6'd1;
                        end
                    end
                end
                
                UPDATE: begin
                    div_in_progress <= 1'b0;
                    
                    // Calculate candidate x
                    if (is_valid_x1) begin
                        // x1 = (a - b) / (2 * k)
                        current_x <= div_quotient;
                    end else if (is_valid_x2) begin
                        // x2 = (a + b) / (2 * k)
                        current_x <= div_quotient;
                    end
                    
                    // Update minimum
                    if (is_valid_x1 || is_valid_x2) begin
                        if (current_x < min_x) begin
                            min_x <= current_x;
                        end
                    end
                end
                
                NEXT_K: begin
                    k <= k + 8'd1;
                    div_in_progress <= 1'b0;
                    div_bit <= 6'd0;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    
                    // Determine final result
                    if (b_fixed > a_fixed) begin
                        result <= NEG_ONE;  // -1
                    end else if (b_fixed == a_fixed) begin
                        result <= a_fixed;  // a
                    end else if (min_x != 32'hFFFFFFFF) begin
                        result <= min_x;    // Found valid x
                    end else begin
                        result <= NEG_ONE;  // No valid x found
                    end
                end
            endcase
        end
    end

endmodule