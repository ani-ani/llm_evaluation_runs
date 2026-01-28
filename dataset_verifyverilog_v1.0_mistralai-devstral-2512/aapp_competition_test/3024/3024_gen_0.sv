module max_palindrome_partition(
    input clk,
    input rst_n,
    input start,
    input [127:0] s,
    input [4:0] len,
    output reg [4:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [4:0] l;
    reg [4:0] r;
    reg [4:0] width;
    reg [4:0] current_count;
    reg [4:0] max_width;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1024;
    
    // Store input string in register array
    reg [3:0] s_reg [0:31];
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            l <= 5'd0;
            r <= 5'd0;
            width <= 5'd0;
            current_count <= 5'd0;
            max_width <= 5'd0;
            cycle_count <= 10'd0;
            result <= 5'd0;
            done <= 1'b0;
            for (i = 0; i < 32; i = i + 1) begin
                s_reg[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        // Load input string into register array
                        for (i = 0; i < 32; i = i + 1) begin
                            s_reg[i] <= s[(i*4)+3:i*4];
                        end
                        l <= 5'd0;
                        r <= len - 5'd1;
                        width <= 5'd0;
                        current_count <= 5'd0;
                        max_width <= r - l + 5'd1;
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Check if we've exceeded max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 5'd1;
                        state <= DONE_STATE;
                    end else if (l > r) begin
                        // Entire string is partitioned
                        if (l == r + 5'd1) begin
                            result <= current_count;
                        end else if (l == r + 5'd2) begin
                            result <= current_count + 5'd1;
                        end else begin
                            result <= 5'd1;
                        end
                        state <= DONE_STATE;
                    end else if (width >= max_width) begin
                        // No match found for any width
                        result <= 5'd1;
                        state <= DONE_STATE;
                    end else begin
                        // Check if substrings match
                        reg match;
                        reg [4:0] j;
                        match = 1'b1;
                        for (j = 0; j <= width; j = j + 1) begin
                            if (s_reg[l + j] != s_reg[r - j]) begin
                                match = 1'b0;
                            end
                        end
                        
                        if (match) begin
                            current_count <= current_count + 5'd2;
                            l <= l + width + 5'd1;
                            r <= r - width - 5'd1;
                            width <= 5'd0;
                            max_width <= r - l + 5'd1;
                        end else begin
                            width <= width + 5'd1;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule