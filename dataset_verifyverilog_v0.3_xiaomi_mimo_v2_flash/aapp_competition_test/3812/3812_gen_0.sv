module string_purifier (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] s_len,
    input wire [3:0] t_len,
    input wire [15:0] s_data,
    input wire [15:0] t_data,
    output reg done,
    output reg [3:0] op_count,
    output reg [15:0] operations
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] SCAN     = 2'd1;
    localparam [1:0] SWAP     = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    // Registers for operation tracking
    reg [1:0] state;
    reg [3:0] current_index;
    reg [3:0] max_ops;
    reg [15:0] s_reg;
    reg [15:0] t_reg;
    reg [3:0] s_len_reg;
    reg [3:0] t_len_reg;
    reg [3:0] op_count_reg;
    reg [15:0] operations_reg;
    reg [3:0] scan_counter;
    localparam [3:0] MAX_OPERATIONS = 4'd16;
    localparam [3:0] MAX_STRING_LEN = 4'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            op_count <= 4'd0;
            operations <= 16'd0;
            current_index <= 4'd0;
            s_reg <= 16'd0;
            t_reg <= 16'd0;
            s_len_reg <= 4'd0;
            t_len_reg <= 4'd0;
            op_count_reg <= 4'd0;
            operations_reg <= 16'd0;
            scan_counter <= 4'd0;
            max_ops <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    op_count_reg <= 4'd0;
                    operations_reg <= 16'd0;
                    current_index <= 4'd0;
                    scan_counter <= 4'd0;
                    if (start) begin
                        s_reg <= s_data;
                        t_reg <= t_data;
                        s_len_reg <= s_len;
                        t_len_reg <= t_len;
                        // Calculate max operations (min of max_len and MAX_OPERATIONS)
                        if (s_len <= MAX_OPERATIONS && t_len <= MAX_OPERATIONS) begin
                            max_ops <= (s_len > t_len) ? s_len : t_len;
                        end else begin
                            max_ops <= MAX_OPERATIONS;
                        end
                        state <= SCAN;
                    end
                end

                SCAN: begin
                    if (scan_counter < max_ops && op_count_reg < MAX_OPERATIONS) begin
                        // Extract bits at current position (from right, index 0 is LSB)
                        // Strings are packed: [15] is position 15, [0] is position 0
                        // Since we scan right to left, start from index 0
                        if (s_reg[current_index] != t_reg[current_index]) begin
                            // Mismatch found - schedule swap
                            state <= SWAP;
                        end else begin
                            // Match - continue scanning
                            current_index <= current_index + 4'd1;
                            scan_counter <= scan_counter + 4'd1;
                            if (scan_counter + 4'd1 >= max_ops) begin
                                state <= COMPLETE;
                            end
                        end
                    end else begin
                        state <= COMPLETE;
                    end
                end

                SWAP: begin
                    // Record operation: 2 bits per operation
                    // 00 = no op, 01 = swap, 10 = invalid (not used)
                    // We'll store length of swap (1-16) in 4 bits per operation
                    // Using 2 bits is too small, so we pack into 16-bit:
                    // Each operation takes 2 bits: 00=no, 01=swap at current position
                    // Actually, let's use 4 bits per operation: position
                    // Format: bits [3:0] = position 0, bits [7:4] = position 1, etc.
                    // But 16 bits / 4 bits = 4 operations max, need 16 ops max
                    // So we need 1 bit per operation: swap or not
                    // Let's use 2 bits per operation: 00=do nothing, 01=swap
                    // ops_reg[1:0] for pos 0, ops_reg[3:2] for pos 1, etc.
                    // This gives 8 operations max with 16 bits - need 16 ops
                    // Use 1 bit per operation (swap or not), stored in [15:0]
                    // bit 0 = swap pos 0, bit 1 = swap pos 1, etc.
                    
                    // Record swap at current_index
                    operations_reg[current_index] <= 1'b1;
                    op_count_reg <= op_count_reg + 4'd1;
                    
                    // Swap bits in s_reg and t_reg
                    // Since we're scanning left to right (index 0 to 15), and swapping,
                    // we can just swap the bits at current_index
                    s_reg[current_index] <= t_reg[current_index];
                    t_reg[current_index] <= s_reg[current_index];
                    
                    // Move to next position
                    current_index <= current_index + 4'd1;
                    scan_counter <= scan_counter + 4'd1;
                    
                    if (scan_counter + 4'd1 >= max_ops || op_count_reg + 4'd1 >= MAX_OPERATIONS) begin
                        state <= COMPLETE;
                    end else begin
                        state <= SCAN;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    op_count <= op_count_reg;
                    operations <= operations_reg;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule