module abacaba_counter(
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
    localparam [1:0] FINISH = 2'd2;

    // Stack entry format: {current_n[31:0], start_index[15:0], end_index[15:0]}
    reg [63:0] stack [0:63];
    reg [5:0] stack_ptr;
    reg [15:0] accumulator;
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // Calculate total length of sequence
    wire [31:0] total_len;
    assign total_len = (n > 32'd1) ? (32'd1 << (32'd32 - $clog2(n))) - 32'd1 : 32'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            stack_ptr <= 6'd0;
            accumulator <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Initialize stack with root node
                        stack[0] <= {n, 16'd1, total_len[15:0]};
                        stack_ptr <= 6'd1;
                        state <= CALC;
                    end
                end

                CALC: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (stack_ptr > 6'd0) begin
                        reg [63:0] current_entry;
                        reg [31:0] current_n;
                        reg [15:0] curr_l, curr_r;
                        reg [15:0] mid_index;
                        reg [15:0] left_len, right_len;
                        reg is_leaf;
                        
                        // Pop from stack
                        stack_ptr <= stack_ptr - 6'd1;
                        current_entry <= stack[stack_ptr];
                        current_n <= current_entry[63:32];
                        curr_l <= current_entry[31:16];
                        curr_r <= current_entry[15:0];
                        
                        // Check if current range is fully within query range
                        if (curr_l >= l && curr_r <= r) begin
                            // Add popcount of current_n
                            accumulator <= accumulator + $countones(current_n);
                        end else if (curr_r < l || curr_l > r) begin
                            // Disjoint, do nothing
                        end else begin
                            // Partially overlapping, push children
                            is_leaf = (current_n <= 32'd1);
                            
                            if (!is_leaf) begin
                                mid_index <= (curr_l + curr_r) / 2;
                                left_len <= mid_index - curr_l;
                                right_len <= curr_r - mid_index;
                                
                                // Push right child
                                if (stack_ptr < 6'd64) begin
                                    stack[stack_ptr] <= {current_n / 2, mid_index + 16'd1, curr_r};
                                    stack_ptr <= stack_ptr + 6'd1;
                                end
                                
                                // Push left child
                                if (stack_ptr < 6'd64) begin
                                    stack[stack_ptr] <= {current_n / 2, curr_l, mid_index - 16'd1};
                                    stack_ptr <= stack_ptr + 6'd1;
                                end
                                
                                // Check center
                                if (mid_index >= l && mid_index <= r) begin
                                    accumulator <= accumulator + (current_n % 2);
                                end
                            end else begin
                                // Leaf node, check if in range
                                if (curr_l >= l && curr_l <= r) begin
                                    accumulator <= accumulator + current_n;
                                end
                            end
                        end
                        
                        // Check if stack is empty or cycle limit reached
                        if (stack_ptr == 6'd0 || cycle_count >= MAX_CYCLES) begin
                            state <= FINISH;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule