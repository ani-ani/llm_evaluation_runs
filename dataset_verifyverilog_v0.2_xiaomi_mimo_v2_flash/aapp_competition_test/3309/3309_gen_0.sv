module media_companies (
    input clk,
    input rst_n,
    input start,
    input [3:0] k_min,
    input [3:0] c_min,
    input [7:0][3:0] sectors,
    output reg [3:0] max_companies,
    output reg done
);

    // States
    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam CHECK_RANGE = 4'd2;
    localparam BUILD_BITMAP = 4'd3;
    localparam VALIDATE = 4'd4;
    localparam SELECT = 4'd5;
    localparam UPDATE_OFFSET = 4'd6;
    localparam DONE = 4'd7;

    reg [3:0] state;
    
    // Datapath Registers
    reg [3:0] global_offset;  // 0-7
    reg [3:0] range_idx;      // 0-7
    reg [3:0] k_idx;          // 0-K-1
    reg [7:0] valid_bitmap;   // Valid flags for ranges 0-7 (current offset)
    reg [15:0] color_bitmap;  // For distinct color counting
    reg [3:0] temp_max;       // Max companies for current offset
    reg [7:0] blocked;        // For greedy selection
    reg [3:0] select_idx;     // 0-7
    
    // Combinational Logic
    wire [3:0] distinct_count;
    
    // Helper to count set bits in color_bitmap (0-16)
    // For N=8, max distinct is 8. We can use a small loop or hardcode.
    // A simple adder tree logic:
    assign distinct_count = color_bitmap[0] + color_bitmap[1] + color_bitmap[2] + color_bitmap[3] + 
                           color_bitmap[4] + color_bitmap[5] + color_bitmap[6] + color_bitmap[7] + 
                           color_bitmap[8] + color_bitmap[9] + color_bitmap[10] + color_bitmap[11] + 
                           color_bitmap[12] + color_bitmap[13] + color_bitmap[14] + color_bitmap[15];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_companies <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) state <= INIT;
                end

                INIT: begin
                    global_offset <= 0;
                    max_companies <= 0;
                    state <= CHECK_RANGE;
                end

                CHECK_RANGE: begin
                    if (global_offset < 8) begin
                        range_idx <= 0;
                        valid_bitmap <= 0;
                        state <= BUILD_BITMAP;
                    end else begin
                        state <= DONE;
                    end
                end

                BUILD_BITMAP: begin
                    // Initialize on first element of range
                    if (k_idx == 0) color_bitmap <= 0;
                    
                    if (k_idx < k_min) begin
                        // Calculate physical index
                        // phys_idx = (range_idx + k_idx + global_offset) % 8
                        // Since global_offset is reg, we compute next value or use temp.
                        // We can use modular arithmetic directly.
                        // To avoid overflow warnings, mask the sum.
                        
                        reg [3:0] phys_idx;
                        phys_idx = (range_idx + k_idx + global_offset) & 4'h7; // Modulo 8
                        
                        // Set bit corresponding to sector value
                        color_bitmap[sectors[phys_idx]] <= 1'b1;
                        
                        k_idx <= k_idx + 1;
                    end else begin
                        k_idx <= 0;
                        state <= VALIDATE;
                    end
                end

                VALIDATE: begin
                    // Check if distinct count meets requirement
                    if (distinct_count >= c_min) begin
                        valid_bitmap[range_idx] <= 1'b1;
                    end
                    
                    if (range_idx < 7) begin
                        range_idx <= range_idx + 1;
                        state <= BUILD_BITMAP;
                    end else begin
                        // Finished all ranges for this offset
                        // Prepare for selection
                        select_idx <= 0;
                        blocked <= 0;
                        temp_max <= 0;
                        state <= SELECT;
                    end
                end

                SELECT: begin
                    if (select_idx < 8) begin
                        // Check if valid and not blocked
                        if (valid_bitmap[select_idx] && !blocked[select_idx]) begin
                            // Select this range
                            temp_max <= temp_max + 1;
                            
                            // Update blocked mask
                            // We need to compute the mask for range [select_idx, select_idx + k_min - 1]
                            // Handle wrap around.
                            // Mask = ((1 << k_min) - 1) << select_idx | ((1 << k_min) - 1) >> (8 - select_idx)
                            // We compute this combinationally or inline.
                            
                            // Inline computation:
                            // 1. Base mask: (1 << k_min) - 1. Ensure k_min is 1..8.
                            // 2. Shift left: base << select_idx (only lower 8 bits matter)
                            // 3. Shift right: base >> (8 - select_idx)
                            
                            // Note: 'blocked' is 8 bits. We assign to it.
                            blocked <= blocked | 
                                      ( ((1 << k_min) - 1) << select_idx ) | 
                                      ( ((1 << k_min) - 1) >> (8 - select_idx) );
                        end
                        select_idx <= select_idx + 1;
                    end else begin
                        // Selection complete
                        if (temp_max > max_companies) begin
                            max_companies <= temp_max;
                        end
                        state <= UPDATE_OFFSET;
                    end
                end

                UPDATE_OFFSET: begin
                    global_offset <= global_offset + 1;
                    state <= CHECK_RANGE;
                end

                DONE: begin
                    done <= 1'b1;
                    if (start) state <= IDLE; // Reset on start if held high
                end
            endcase
        end
    end
endmodule
