module ratio_splitter_network(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a_in,
    input wire [31:0] b_in,
    input wire [31:0] c_in,
    input wire [31:0] d_in,
    output reg done,
    output reg [7:0] node_count,
    output reg [7:0] left_child,
    output reg [7:0] right_child,
    output reg output_valid,
    output reg [7:0] current_node
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] SETUP        = 3'd1;
    localparam [2:0] COMPUTE_GCD  = 3'd2;
    localparam [2:0] CALCULATE    = 3'd3;
    localparam [2:0] OUTPUT_NODE  = 3'd4;
    localparam [2:0] CHECK_FINISH = 3'd5;
    localparam [2:0] DONE         = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    
    // Working variables for Euclidean algorithm
    reg [31:0] A, B, C, D;
    reg [31:0] next_A, next_B, next_C, next_D;
    
    // GCD computation registers
    reg [31:0] gcd_x, gcd_y;
    reg [31:0] gcd_temp;
    reg [31:0] norm_a, norm_b, norm_c, norm_d;
    
    // Node storage (max 200 nodes)
    reg [7:0] left_child_mem [0:199];
    reg [7:0] right_child_mem [0:199];
    
    // Stack for recursion tracking
    reg [31:0] stack_A [0:199];
    reg [31:0] stack_B [0:199];
    reg [31:0] stack_C [0:199];
    reg [31:0] stack_D [0:199];
    reg [7:0] stack_ptr;
    reg [7:0] next_stack_ptr;
    
    // Counter for node output
    reg [7:0] output_idx;
    reg [7:0] next_output_idx;
    
    // Cycle counter for timeout
    reg [15:0] cycle_count;
    
    // Internal control signals
    reg start_calc;
    reg output_done;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            node_count <= 8'd0;
            left_child <= 8'd0;
            right_child <= 8'd0;
            output_valid <= 1'b0;
            current_node <= 8'd0;
            A <= 32'd0;
            B <= 32'd0;
            C <= 32'd0;
            D <= 32'd0;
            norm_a <= 32'd0;
            norm_b <= 32'd0;
            norm_c <= 32'd0;
            norm_d <= 32'd0;
            gcd_x <= 32'd0;
            gcd_y <= 32'd0;
            stack_ptr <= 8'd0;
            output_idx <= 8'd0;
            cycle_count <= 16'd0;
            start_calc <= 1'b0;
            output_done <= 1'b0;
            // Initialize memory arrays
            for (i = 0; i < 200; i = i + 1) begin
                left_child_mem[i] <= 8'd0;
                right_child_mem[i] <= 8'd0;
                stack_A[i] <= 32'd0;
                stack_B[i] <= 32'd0;
                stack_C[i] <= 32'd0;
                stack_D[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            A <= next_A;
            B <= next_B;
            C <= next_C;
            D <= next_D;
            stack_ptr <= next_stack_ptr;
            output_idx <= next_output_idx;
            start_calc <= (state == SETUP && next_state == COMPUTE_GCD);
            output_done <= (state == OUTPUT_NODE && next_state == CHECK_FINISH);
            
            // Cycle counter increment
            if (state == IDLE) begin
                cycle_count <= 16'd0;
            end else if (state != DONE) begin
                if (cycle_count < 16'd20000) begin
                    cycle_count <= cycle_count + 16'd1;
                end
            end
            
            // Handle node output storage
            if (state == CALCULATE && next_state == OUTPUT_NODE) begin
                if (stack_ptr < 8'd200) begin
                    left_child_mem[stack_ptr] <= left_child;
                    right_child_mem[stack_ptr] <= right_child;
                end
            end
            
            // Handle output streaming
            if (state == OUTPUT_NODE) begin
                output_valid <= 1'b1;
                current_node <= output_idx;
                left_child <= left_child_mem[output_idx];
                right_child <= right_child_mem[output_idx];
            end else begin
                output_valid <= 1'b0;
            end
            
            // Set node count when done
            if (state == DONE) begin
                node_count <= stack_ptr;
            end
            
            // Set done signal
            if (state == DONE) begin
                done <= 1'b1;
            end else if (state == IDLE) begin
                done <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_A = A;
        next_B = B;
        next_C = C;
        next_D = D;
        next_stack_ptr = stack_ptr;
        next_output_idx = output_idx;
        
        left_child = 8'd0;
        right_child = 8'd0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP;
                end
            end
            
            SETUP: begin
                // Load inputs and initialize
                next_A = a_in;
                next_B = b_in;
                next_C = c_in;
                next_D = d_in;
                next_stack_ptr = 8'd0;
                next_output_idx = 8'd0;
                next_state = COMPUTE_GCD;
            end
            
            COMPUTE_GCD: begin
                // Compute GCD for normalization
                // This is a simplified sequential GCD
                if (A == 32'd0 || B == 32'd0) begin
                    next_A = (A == 32'd0) ? B : A;
                    next_B = 32'd0;
                    next_state = CALCULATE;
                end else if (A > B) begin
                    next_A = A - B;
                    next_B = B;
                end else begin
                    next_A = A;
                    next_B = B - A;
                end
                
                // Check if GCD computation is complete
                if (next_A == 32'd0 || next_B == 32'd0) begin
                    next_state = CALCULATE;
                end
            end
            
            CALCULATE: begin
                // Perform normalization and Euclidean step
                // Normalization already done in GCD step (A contains gcd)
                norm_a = (a_in / (A + B == 0 ? 32'd1 : A + B));
                norm_b = (b_in / (A + B == 0 ? 32'd1 : A + B));
                norm_c = (c_in / (C + D == 0 ? 32'd1 : C + D));
                norm_d = (d_in / (C + D == 0 ? 32'd1 : C + D));
                
                // Euclidean algorithm step
                if (C >= A) begin
                    // Case 1: C >= A
                    next_C = C - A;
                    next_D = D;
                    // Node routes A/(A+B) to left, remaining to right
                    left_child = stack_ptr + 8'd1;  // New sub-splitter
                    right_child = 8'd255;  // Global output -1
                    next_stack_ptr = stack_ptr + 8'd1;
                    // Push sub-problem to stack
                    stack_A[next_stack_ptr] = A;
                    stack_B[next_stack_ptr] = B;
                    stack_C[next_stack_ptr] = C - A;
                    stack_D[next_stack_ptr] = D;
                end else begin
                    // Case 2: C < A (implied D > B)
                    next_C = C;
                    next_D = D - B;
                    // Node routes B/(A+B) to left, remaining to right
                    left_child = stack_ptr + 8'd1;  // New sub-splitter
                    right_child = 8'd255;  // Global output -1
                    next_stack_ptr = stack_ptr + 8'd1;
                    // Push sub-problem to stack
                    stack_A[next_stack_ptr] = A;
                    stack_B[next_stack_ptr] = B;
                    stack_C[next_stack_ptr] = C;
                    stack_D[next_stack_ptr] = D - B;
                end
                
                next_state = OUTPUT_NODE;
            end
            
            OUTPUT_NODE: begin
                // Output current node and prepare next
                if (output_idx < stack_ptr) begin
                    next_output_idx = output_idx + 8'd1;
                    next_state = OUTPUT_NODE;
                    // Load next node values from stack
                    next_A = stack_A[output_idx + 8'd1];
                    next_B = stack_B[output_idx + 8'd1];
                    next_C = stack_C[output_idx + 8'd1];
                    next_D = stack_D[output_idx + 8'd1];
                end else begin
                    next_state = CHECK_FINISH;
                end
            end
            
            CHECK_FINISH: begin
                // Check termination conditions
                if (C == 32'd0 && D == 32'd0) begin
                    next_state = DONE;
                end else if (C == 32'd0) begin
                    // D > 0, route to output -2
                    left_child = 8'd254;  // Global output -2
                    right_child = 8'd255;
                    next_state = DONE;
                end else if (D == 32'd0) begin
                    // C > 0, route to output -1
                    left_child = 8'd255;
                    right_child = 8'd254;
                    next_state = DONE;
                end else if (cycle_count >= 16'd20000) begin
                    // Timeout protection
                    next_state = DONE;
                end else begin
                    // Continue recursion
                    next_state = CALCULATE;
                end
            end
            
            DONE: begin
                // Stay in DONE state until reset
                next_state = DONE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule