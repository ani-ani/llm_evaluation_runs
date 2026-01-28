module CountOnesAbacaba(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] n,
    input wire [15:0] l,
    input wire [15:0] r,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    reg [1:0] state;
    
    // Stack parameters
    localparam [5:0] MAX_STACK = 6'd32;
    
    // Stack registers (using arrays)
    reg [31:0] stack_n [0:31];
    reg [15:0] stack_start [0:31];
    reg [15:0] stack_end [0:31];
    reg [5:0] stack_ptr;
    
    // Working registers
    reg [31:0] curr_n;
    reg [15:0] curr_start;
    reg [15:0] curr_end;
    reg [15:0] acc;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Helper: Calculate total length of sequence for given n
    function automatic [15:0] calc_length;
        input [31:0] val;
        reg [5:0] bit_len;
        integer i;
        begin
            if (val <= 32'd1) begin
                calc_length = 16'd1;
            end else begin
                bit_len = 6'd0;
                for (i = 0; i < 32; i = i + 1) begin
                    if (val[i]) bit_len = i + 1;
                end
                // length = (1 << bit_len) - 1
                calc_length = (16'd1 << bit_len) - 16'd1;
            end
        end
    endfunction
    
    // Helper: Popcount for 32-bit (simple iterative)
    function automatic [5:0] popcount32;
        input [31:0] val;
        reg [5:0] cnt;
        integer i;
        begin
            cnt = 6'd0;
            for (i = 0; i < 32; i = i + 1) begin
                if (val[i]) cnt = cnt + 6'd1;
            end
            popcount32 = cnt;
        end
    endfunction
    
    // Combinational logic for next state
    always @(*) begin
        // Default assignments
        curr_n = 32'd0;
        curr_start = 16'd0;
        curr_end = 16'd0;
        
        if (state == CALC) begin
            if (stack_ptr > 6'd0) begin
                // Pop from stack
                curr_n = stack_n[stack_ptr - 1];
                curr_start = stack_start[stack_ptr - 1];
                curr_end = stack_end[stack_ptr - 1];
            end
        end
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            stack_ptr <= 6'd0;
            acc <= 16'd0;
            // Initialize stack arrays
            for (integer i = 0; i < 32; i = i + 1) begin
                stack_n[i] <= 32'd0;
                stack_start[i] <= 16'd0;
                stack_end[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        acc <= 16'd0;
                        stack_ptr <= 6'd0;
                        // Push initial range
                        stack_n[0] <= n;
                        stack_start[0] <= 16'd1;
                        stack_end[0] <= calc_length(n);
                        stack_ptr <= 6'd1;
                        state <= CALC;
                    end
                end
                
                CALC: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (stack_ptr == 6'd0 || cycle_count >= MAX_CYCLES) begin
                        // Stack empty or timeout
                        result <= acc;
                        state <= DONE;
                    end else begin
                        // Process current node (already in curr_* from comb logic)
                        // Check overlap with query [l, r]
                        if (curr_end < l || curr_start > r) begin
                            // No overlap - just pop (decrement ptr)
                            stack_ptr <= stack_ptr - 6'd1;
                        end else if (l <= curr_start && curr_end <= r) begin
                            // Fully inside - add popcount and pop
                            acc <= acc + popcount32(curr_n);
                            stack_ptr <= stack_ptr - 6'd1;
                        end else begin
                            // Partial overlap - expand node
                            // Pop current node first
                            stack_ptr <= stack_ptr - 6'd1;
                            
                            // Calculate mid index
                            if (curr_n <= 32'd1) begin
                                // Leaf node - if overlap, add value
                                if (curr_n[0]) acc <= acc + 16'd1;
                            end else begin
                                // Internal node
                                // Push right child
                                if (stack_ptr < MAX_STACK) begin
                                    stack_n[stack_ptr - 1] <= curr_n >> 1; // n/2
                                    stack_start[stack_ptr - 1] <= curr_start + ((curr_end - curr_start) >> 1) + 1;
                                    stack_end[stack_ptr - 1] <= curr_end;
                                    stack_ptr <= stack_ptr;
                                end
                                
                                // Push center bit if in range
                                if ((curr_start + ((curr_end - curr_start) >> 1)) >= l && 
                                    (curr_start + ((curr_end - curr_start) >> 1)) <= r) begin
                                    if (curr_n[0]) acc <= acc + 16'd1;
                                end
                                
                                // Push left child
                                if (stack_ptr < MAX_STACK) begin
                                    stack_n[stack_ptr - 1] <= curr_n >> 1; // n/2
                                    stack_start[stack_ptr - 1] <= curr_start;
                                    stack_end[stack_ptr - 1] <= curr_start + ((curr_end - curr_start) >> 1) - 1;
                                    stack_ptr <= stack_ptr;
                                end
                            end
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule