module array_restore(
    input wire clk,
    input wire rst_n,
    input wire start,
    input [3:0] n,
    input [3:0] q,
    input [3:0] a_0,
    input [3:0] a_1,
    input [3:0] a_2,
    input [3:0] a_3,
    input [3:0] a_4,
    input [3:0] a_5,
    input [3:0] a_6,
    input [3:0] a_7,
    input [3:0] a_8,
    input [3:0] a_9,
    input [3:0] a_10,
    input [3:0] a_11,
    input [3:0] a_12,
    input [3:0] a_13,
    input [3:0] a_14,
    input [3:0] a_15,
    output reg done,
    output reg valid,
    output reg [3:0] result_0,
    output reg [3:0] result_1,
    output reg [3:0] result_2,
    output reg [3:0] result_3,
    output reg [3:0] result_4,
    output reg [3:0] result_5,
    output reg [3:0] result_6,
    output reg [3:0] result_7,
    output reg [3:0] result_8,
    output reg [3:0] result_9,
    output reg [3:0] result_10,
    output reg [3:0] result_11,
    output reg [3:0] result_12,
    output reg [3:0] result_13,
    output reg [3:0] result_14,
    output reg [3:0] result_15
);

    // State declarations
    localparam [3:0]
        INIT            = 4'd0,
        BACKWARD_PASS   = 4'd1,
        INIT_FORWARD    = 4'd2,
        FORWARD         = 4'd3,
        AFTER_FORWARD   = 4'd4,
        FIND_ZERO       = 4'd5,
        OUTPUT_VALID    = 4'd6,
        OUTPUT_INVALID  = 4'd7;
    
    reg [3:0] state, next_state;
    
    // Working arrays
    reg [3:0] array       [0:15];
    reg [3:0] last_occur  [0:15];
    
    // Stack variables
    reg [3:0] stack [0:3];
    reg [1:0] sp;
    reg [3:0] current_max;
    
    // Counters
    reg [3:0] i;
    reg [4:0] cycle_count;
    
    // Flags
    reg is_valid;
    reg zero_found;
    
    // Temporary registers
    reg [3:0] n_minus_1;
    reg [3:0] temp_a;
    
    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            valid <= 1'b0;
            state <= INIT;
            
            // Initialize arrays and stack
            for (idx = 0; idx < 16; idx = idx + 1) begin
                array[idx] <= 4'd0;
                last_occur[idx] <= 4'd0;
                result_0 <= 4'd0;
                result_1 <= 4'd0;
                result_2 <= 4'd0;
                result_3 <= 4'd0;
                result_4 <= 4'd0;
                result_5 <= 4'd0;
                result_6 <= 4'd0;
                result_7 <= 4'd0;
                result_8 <= 4'd0;
                result_9 <= 4'd0;
                result_10 <= 4'd0;
                result_11 <= 4'd0;
                result_12 <= 4'd0;
                result_13 <= 4'd0;
                result_14 <= 4'd0;
                result_15 <= 4'd0;
            end
            
            for (idx = 0; idx < 4; idx = idx + 1) begin
                stack[idx] <= 4'd0;
            end
            
            i <= 4'd0;
            sp <= 2'd0;
            current_max <= 4'd0;
            is_valid <= 1'b1;
            zero_found <= 1'b0;
            cycle_count <= 5'd0;
            n_minus_1 <= 4'd0;
        end else begin
            cycle_count <= cycle_count + 5'd1;
            state <= next_state;
            
            case (state)
                INIT: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    
                    // Load input array
                    array[0] <= a_0;
                    array[1] <= a_1;
                    array[2] <= a_2;
                    array[3] <= a_3;
                    array[4] <= a_4;
                    array[5] <= a_5;
                    array[6] <= a_6;
                    array[7] <= a_7;
                    array[8] <= a_8;
                    array[9] <= a_9;
                    array[10] <= a_10;
                    array[11] <= a_11;
                    array[12] <= a_12;
                    array[13] <= a_13;
                    array[14] <= a_14;
                    array[15] <= a_15;
                    
                    // Clear last_occur
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        last_occur[idx] <= 4'd0;
                    end
                    
                    if (start) begin
                        n_minus_1 <= (n > 0) ? (n - 4'd1) : 4'd0;
                        sp <= 2'd0;
                        current_max <= 4'd0;
                        is_valid <= 1'b1;
                        i <= 4'd0;
                        cycle_count <= 5'd0;
                        next_state <= BACKWARD_PASS;
                    end else begin
                        next_state <= INIT;
                    end
                end
                
                BACKWARD_PASS: begin
                    if (i < n) begin
                        temp_a <= array[n_minus_1 - i];
                        
                        if (array[n_minus_1 - i] != 4'd0) begin
                            if (last_occur[array[n_minus_1 - i]] == 4'd0) begin
                                last_occur[array[n_minus_1 - i]] <= (n_minus_1 - i) + 4'd1;
                            end
                        end
                        
                        i <= i + 4'd1;
                        next_state <= BACKWARD_PASS;
                    end else begin
                        i <= 4'd0;
                        next_state <= INIT_FORWARD;
                    end
                end
                
                INIT_FORWARD: begin
                    current_max <= 4'd0;
                    sp <= 2'd0;
                    zero_found <= 1'b0;
                    i <= 4'd0;
                    next_state <= FORWARD;
                end
                
                FORWARD: begin
                    if (i < n) begin
                        if (array[i] == 4'd0) begin
                            // Replace zero
                            array[i] <= (current_max == 4'd0) ? 4'd1 : current_max;
                            zero_found <= 1'b1;
                        end else begin
                            if (array[i] > current_max) begin
                                if (i != (last_occur[current_max] - 4'd1)) begin
                                    // Push to stack
                                    stack[sp] <= current_max;
                                    sp <= sp + 2'd1;
                                end
                                current_max <= array[i];
                            end else if (array[i] < current_max) begin
                                is_valid <= 1'b0;
                            end
                        
                            if (i == (last_occur[current_max] - 4'd1)) begin
                                // Pop stack
                                sp <= sp - 2'd1;
                                current_max <= stack[sp - 2'd1];
                            end
                        end
                        
                        i <= i + 4'd1;
                        next_state <= FORWARD;
                    end else begin
                        next_state <= AFTER_FORWARD;
                    end
                end
                
                AFTER_FORWARD: begin
                    if (current_max != q && is_valid) begin
                        // Need to fix one zero to q
                        if (current_max < q && zero_found) begin
                            next_state <= FIND_ZERO;
                        end else begin
                            is_valid <= 1'b0;
                            next_state <= OUTPUT_INVALID;
                        end
                    end else if (!is_valid) begin
                        next_state <= OUTPUT_INVALID;
                    end else begin
                        next_state <= OUTPUT_VALID;
                    end
                end
                
                FIND_ZERO: begin
                    // Find the last zero to replace with q
                    if (array[i] == q) begin
                        // Already present, check max
                        if (current_max != q) begin
                            array[i] <= q;
                        end
                        next_state <= OUTPUT_VALID;
                    end else begin
                        if (array[i] == (current_max == 4'd0 ? 4'd1 : current_max)) begin
                            array[i] <= q;
                            current_max <= q;
                            next_state <= OUTPUT_VALID;
                        end else if (i > 0) begin
                            i <= i - 4'd1;
                            next_state <= FIND_ZERO;
                        end else begin
                            // No replaceable zero found
                            is_valid <= 1'b0;
                            next_state <= OUTPUT_INVALID;
                        end
                    end
                end
                
                OUTPUT_VALID: begin
                    valid <= 1'b1;
                    done <= 1'b1;
                    // Assign results
                    result_0 <= array[0];
                    result_1 <= array[1];
                    result_2 <= array[2];
                    result_3 <= array[3];
                    result_4 <= array[4];
                    result_5 <= array[5];
                    result_6 <= array[6];
                    result_7 <= array[7];
                    result_8 <= array[8];
                    result_9 <= array[9];
                    result_10 <= array[10];
                    result_11 <= array[11];
                    result_12 <= array[12];
                    result_13 <= array[13];
                    result_14 <= array[14];
                    result_15 <= array[15];
                    
                    if (!start) begin
                        next_state <= INIT;
                    end
                end
                
                OUTPUT_INVALID: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    
                    if (!start) begin
                        next_state <= INIT;
                    end
                end
                
                default: begin
                    next_state <= INIT;
                end
            endcase
        end
    end
endmodule
