module generate_smallest_string(
    input clk,
    input rst_n,
    input start,
    input [15:0] n_in,
    input [7:0] k_in,
    output reg [127:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] GENERATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Registers
    reg [1:0] state;
    reg [15:0] n_reg;
    reg [7:0] k_reg;
    reg [15:0] pos;           // Position counter
    reg [7:0] char_idx;       // Current character index (0=a, 1=b, 2=c, ...)
    reg [7:0] next_char;      // Next character to store
    reg error_flag;
    reg [7:0] char_counter;   // Count generated characters
    reg [15:0] cycle_count;   // Prevent infinite loops
    localparam [15:0] MAX_CYCLES = 16'd256;
    
    // Character generation control
    reg start_alt;            // Flag to start alternating pattern
    reg [7:0] alt_char;       // Alternating character (a or b)
    reg [7:0] distinct_char;  // Distinct character counter (c, d, e, ...)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 128'd0;
            done <= 1'b0;
            valid <= 1'b0;
            n_reg <= 16'd0;
            k_reg <= 8'd0;
            pos <= 16'd0;
            char_idx <= 8'd0;
            next_char <= 8'd0;
            error_flag <= 1'b0;
            char_counter <= 8'd0;
            cycle_count <= 16'd0;
            start_alt <= 1'b0;
            alt_char <= 8'd0;
            distinct_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    char_counter <= 8'd0;
                    result <= 128'd0;
                    
                    if (start) begin
                        n_reg <= n_in;
                        k_reg <= k_in;
                        state <= CHECK;
                        valid <= 1'b0;  // Clear valid on new request
                    end
                end
                
                CHECK: begin
                    // Validate inputs and check impossibility conditions
                    if (k_reg > 8'd16) begin
                        error_flag <= 1'b1;
                    end else if (k_reg > n_reg) begin
                        error_flag <= 1'b1;
                    end else if (k_reg == 8'd1 && n_reg > 16'd1) begin
                        error_flag <= 1'b1;
                    end else begin
                        error_flag <= 1'b0;
                    end
                    
                    // Special case: n==1 && k==1
                    if (n_reg == 16'd1 && k_reg == 8'd1 && !error_flag) begin
                        // Will handle in generate state
                    end
                    
                    // Setup for generation
                    pos <= 16'd0;
                    char_idx <= 8'd0;
                    alt_char <= 8'd0;       // 'a' at index 0
                    distinct_char <= 8'd2;  // Start at 'c' (index 2)
                    result <= 128'd0;
                    start_alt <= 1'b0;
                    
                    state <= GENERATE;
                end
                
                GENERATE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    if (error_flag) begin
                        // Generate error pattern (all 0xFF)
                        if (pos < 16'd16) begin
                            // Store 0xFF in current position
                            result[(pos * 8) +: 8] <= 8'hFF;
                            pos <= pos + 16'd1;
                        end else begin
                            // Done generating error pattern
                            valid <= 1'b1;
                            state <= DONE_STATE;
                        end
                    end
                    else if (n_reg == 16'd1 && k_reg == 8'd1) begin
                        // Special case: single 'a'
                        result[7:0] <= 8'h61;  // 'a'
                        valid <= 1'b1;
                        state <= DONE_STATE;
                    end
                    else begin
                        // Normal generation logic
                        if (pos < n_reg && pos < 16'd16) begin
                            // Determine which character to store
                            if (pos == 16'd0) begin
                                // First character is always 'a'
                                next_char <= 8'd0;
                            end else if (pos == 16'd1) begin
                                // Second character is 'b' (if k > 1)
                                if (k_reg > 8'd1) begin
                                    next_char <= 8'd1;
                                    start_alt <= 1'b1;
                                end else begin
                                    next_char <= 8'd0;  // Should not happen with k==1
                                end
                            end else begin
                                // For subsequent characters
                                if (k_reg == 8'd2) begin
                                    // Only 'a' and 'b' allowed
                                    alt_char <= ~alt_char[0];  // Toggle
                                    next_char <= alt_char[0] ? 8'd1 : 8'd0;
                                end else begin
                                    // k >= 3 case
                                    if (pos <= (n_reg - k_reg + 16'd2)) begin
                                        // Alternating 'a' and 'b' phase
                                        alt_char <= ~alt_char[0];
                                        next_char <= alt_char[0] ? 8'd1 : 8'd0;
                                    end else begin
                                        // Distinct characters phase
                                        next_char <= distinct_char;
                                        distinct_char <= distinct_char + 8'd1;
                                    end
                                end
                            end
                            
                            // Pack character into result
                            result[(pos * 8) +: 8] <= next_char + 8'h61;  // Convert to ASCII
                            pos <= pos + 16'd1;
                        end else begin
                            // String generation complete
                            if (pos >= n_reg || pos >= 16'd16) begin
                                valid <= 1'b1;
                                state <= DONE_STATE;
                            end
                        end
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        valid <= 1'b1;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                    // valid remains high
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule