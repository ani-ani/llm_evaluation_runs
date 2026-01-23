module odd_collatz (
    input clk,
    input rst_n,
    input start,
    input [31:0] n,
    output reg [31:0] result,
    output reg done,
    output reg [3:0] count
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam GENERATE = 3'b001;
    localparam CHECK_ODD = 3'b010;
    localparam SORT = 3'b011;
    localparam PACK = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Data path registers
    reg [31:0] current_val;
    reg [5:0] step_count;      // Counts up to 32
    reg [3:0] odd_count;       // Number of odd numbers found (0-8)
    
    // Odd list storage (max 8 elements, 4 bits each)
    reg [3:0] odd_list [0:7];
    
    // Sorting variables
    reg [2:0] sort_idx;        // Index for sorting
    reg [2:0] sort_j;          // Inner loop index
    reg swap_flag;             // Flag to indicate swap needed
    
    // Temporary calculation registers
    reg [31:0] next_val;
    reg is_odd;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = GENERATE;
                else
                    next_state = IDLE;
            end
            
            GENERATE: begin
                next_state = CHECK_ODD;
            end
            
            CHECK_ODD: begin
                // Store odd number if found, check termination
                if (step_count >= 32 || current_val == 1)
                    next_state = SORT;
                else
                    next_state = GENERATE;
            end
            
            SORT: begin
                // Bubble sort completion check
                if (sort_idx >= odd_count - 1) 
                    next_state = PACK;
                else
                    next_state = SORT;
            end
            
            PACK: begin
                next_state = DONE;
            end
            
            DONE: begin
                if (start)
                    next_state = GENERATE;
                else
                    next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State register and control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'b0;
            done <= 1'b0;
            count <= 4'b0;
            current_val <= 32'b0;
            step_count <= 6'b0;
            odd_count <= 4'b0;
            sort_idx <= 3'b0;
            sort_j <= 3'b0;
            swap_flag <= 1'b0;
            // Initialize odd_list to avoid latch inference
            odd_list[0] <= 4'b0;
            odd_list[1] <= 4'b0;
            odd_list[2] <= 4'b0;
            odd_list[3] <= 4'b0;
            odd_list[4] <= 4'b0;
            odd_list[5] <= 4'b0;
            odd_list[6] <= 4'b0;
            odd_list[7] <= 4'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        current_val <= n;
                        step_count <= 6'b0;
                        odd_count <= 4'b0;
                        done <= 1'b0;
                    end
                end
                
                GENERATE: begin
                    // Determine if current is odd
                    is_odd <= current_val[0];
                    
                    // Calculate next value based on Collatz rules
                    if (current_val[0]) begin
                        // Odd: 3n + 1
                        next_val <= (current_val << 1) + current_val + 1;
                    end else begin
                        // Even: n >> 1
                        next_val <= current_val >> 1;
                    end
                end
                
                CHECK_ODD: begin
                    // Store odd number if space available
                    if (is_odd && odd_count < 8) begin
                        odd_list[odd_count] <= current_val[3:0];
                        odd_count <= odd_count + 1;
                    end
                    
                    // Update current value and step counter
                    current_val <= next_val;
                    step_count <= step_count + 1;
                end
                
                SORT: begin
                    // Bubble sort implementation
                    // Outer loop index is sort_idx, inner loop runs from 0 to odd_count-sort_idx-2
                    if (sort_idx < odd_count - 1) begin
                        if (sort_j < odd_count - sort_idx - 2) begin
                            // Comparison and swap logic
                            if (odd_list[sort_j] > odd_list[sort_j + 1]) begin
                                // Swap
                                odd_list[sort_j] <= odd_list[sort_j + 1];
                                odd_list[sort_j + 1] <= odd_list[sort_j];
                            end
                            sort_j <= sort_j + 1;
                        end else begin
                            // Reset inner loop and increment outer loop
                            sort_j <= 3'b0;
                            sort_idx <= sort_idx + 1;
                        end
                    end else begin
                        // Sorting complete
                        sort_idx <= 3'b0;
                    end
                end
                
                PACK: begin
                    // Pack sorted odd numbers into result
                    result[3:0] <= (odd_count > 0) ? odd_list[0] : 4'b0;
                    result[7:4] <= (odd_count > 1) ? odd_list[1] : 4'b0;
                    result[11:8] <= (odd_count > 2) ? odd_list[2] : 4'b0;
                    result[15:12] <= (odd_count > 3) ? odd_list[3] : 4'b0;
                    result[19:16] <= (odd_count > 4) ? odd_list[4] : 4'b0;
                    result[23:20] <= (odd_count > 5) ? odd_list[5] : 4'b0;
                    result[27:24] <= (odd_count > 6) ? odd_list[6] : 4'b0;
                    result[31:28] <= (odd_count > 7) ? odd_list[7] : 4'b0;
                    count <= odd_count;
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        // Reset for new computation
                        current_val <= n;
                        step_count <= 6'b0;
                        odd_count <= 4'b0;
                        done <= 1'b0;
                        sort_idx <= 3'b0;
                        sort_j <= 3'b0;
                        // Clear result and count
                        result <= 32'b0;
                        count <= 4'b0;
                    end
                end
            endcase
        end
    end

endmodule

module top (
    input clk,
    input rst_n,
    input start,
    input [31:0] n,
    output [31:0] result,
    output done,
    output [3:0] count
);
    odd_collatz oc (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .n(n),
        .result(result),
        .done(done),
        .count(count)
    );
endmodule