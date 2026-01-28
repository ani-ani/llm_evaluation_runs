module ReachableTarget (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [13:0] a,
    input wire signed [13:0] b,
    input wire [3:0] seq_len,
    input wire [1:0] cmd [0:15],
    output reg done,
    output reg result
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PRECALC = 2'd1;
    localparam [1:0] CHECK   = 2'd2;
    localparam [1:0] FINISH  = 2'd3;

    reg [1:0] state, next_state;
    
    // Position registers (16-bit signed)
    reg signed [15:0] x, y;
    reg signed [15:0] dx, dy;
    
    // Intermediate position storage (17 positions: start + 16 commands)
    reg signed [15:0] pos_x [0:16];
    reg signed [15:0] pos_y [0:16];
    
    // Loop counters
    reg [4:0] idx;  // 0 to 16
    reg [4:0] cmd_idx;  // 0 to 15
    
    // Check variables
    reg signed [31:0] diff_a, diff_b;
    reg signed [31:0] quot_a, quot_b;
    reg signed [31:0] rem_a, rem_b;
    reg [4:0] check_idx;
    
    // Cycle counter to prevent infinite loops
    reg [6:0] cycle_count;
    localparam [6:0] MAX_CYCLES = 7'd100;
    
    // Temporary variables for calculations
    reg signed [15:0] new_x, new_y;
    reg signed [31:0] temp_a, temp_b;
    reg signed [31:0] temp_div_a, temp_div_b;
    reg [15:0] abs_a, abs_b;
    
    // Helper signals
    reg check_pass;
    reg is_div_zero_a, is_div_zero_b;
    
    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            cycle_count <= 7'd0;
            // Initialize all registers
            x <= 16'sd0;
            y <= 16'sd0;
            dx <= 16'sd0;
            dy <= 16'sd0;
            idx <= 5'd0;
            cmd_idx <= 5'd0;
            check_idx <= 5'd0;
            diff_a <= 32'sd0;
            diff_b <= 32'sd0;
            quot_a <= 32'sd0;
            quot_b <= 32'sd0;
            rem_a <= 32'sd0;
            rem_b <= 32'sd0;
            new_x <= 16'sd0;
            new_y <= 16'sd0;
            temp_a <= 32'sd0;
            temp_b <= 32'sd0;
            temp_div_a <= 32'sd0;
            temp_div_b <= 32'sd0;
            abs_a <= 16'd0;
            abs_b <= 16'd0;
            check_pass <= 1'b0;
            is_div_zero_a <= 1'b0;
            is_div_zero_b <= 1'b0;
            for (i = 0; i < 17; i = i + 1) begin
                pos_x[i] <= 16'sd0;
                pos_y[i] <= 16'sd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 7'd0;
                    x <= 16'sd0;
                    y <= 16'sd0;
                    idx <= 5'd0;
                    check_idx <= 5'd0;
                end
                
                PRECALC: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    if (cmd_idx < seq_len && cmd_idx < 16) begin
                        case (cmd[cmd_idx])
                            2'b00: new_x <= x + 16'sd1;  // 'U'
                            2'b01: new_y <= y + 16'sd1;  // 'D'
                            2'b10: new_x <= x - 16'sd1;  // 'L'
                            2'b11: new_y <= y - 16'sd1;  // 'R'
                            default: begin
                                new_x <= x;
                                new_y <= y;
                            end
                        endcase
                        
                        // Store position after command
                        if (cmd[cmd_idx] == 2'b00 || cmd[cmd_idx] == 2'b10) begin
                            x <= new_x;
                            pos_x[cmd_idx + 5'd1] <= new_x;
                            pos_y[cmd_idx + 5'd1] <= y;
                        end else begin
                            y <= new_y;
                            pos_x[cmd_idx + 5'd1] <= x;
                            pos_y[cmd_idx + 5'd1] <= new_y;
                        end
                        
                        cmd_idx <= cmd_idx + 5'd1;
                    end else begin
                        // Store final position and calculate net displacement
                        pos_x[0] <= 16'sd0;
                        pos_y[0] <= 16'sd0;
                        pos_x[seq_len] <= x;
                        pos_y[seq_len] <= y;
                        dx <= x;
                        dy <= y;
                        cmd_idx <= 5'd0;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    // Check current intermediate position
                    if (check_idx <= seq_len) begin
                        // Calculate differences
                        diff_a <= $signed({18'd0, a}) - $signed({18'd0, pos_x[check_idx]});
                        diff_b <= $signed({18'd0, b}) - $signed({18'd0, pos_y[check_idx]});
                        
                        is_div_zero_a <= (dx == 16'sd0);
                        is_div_zero_b <= (dy == 16'sd0);
                        
                        // Check if dx or dy is zero
                        if (dx == 16'sd0 && dy == 16'sd0) begin
                            // Both zero: only check exact match
                            if (a == pos_x[check_idx] && b == pos_y[check_idx]) begin
                                check_pass <= 1'b1;
                            end else begin
                                check_pass <= 1'b0;
                            end
                        end else if (dx == 16'sd0) begin
                            // dx is zero
                            if (a == pos_x[check_idx]) begin
                                // Check if (b - yi) has same sign as dy and divisible
                                if ((diff_b > 0 && dy > 0) || (diff_b < 0 && dy < 0) || (diff_b == 0)) begin
                                    // Check divisibility
                                    temp_div_b <= diff_b / dy;
                                    rem_b <= diff_b % dy;
                                    if (diff_b % dy == 0) begin
                                        check_pass <= 1'b1;
                                    end else begin
                                        check_pass <= 1'b0;
                                    end
                                end else begin
                                    check_pass <= 1'b0;
                                end
                            end else begin
                                check_pass <= 1'b0;
                            end
                        end else if (dy == 16'sd0) begin
                            // dy is zero
                            if (b == pos_y[check_idx]) begin
                                // Check if (a - xi) has same sign as dx and divisible
                                if ((diff_a > 0 && dx > 0) || (diff_a < 0 && dx < 0) || (diff_a == 0)) begin
                                    // Check divisibility
                                    temp_div_a <= diff_a / dx;
                                    rem_a <= diff_a % dx;
                                    if (diff_a % dx == 0) begin
                                        check_pass <= 1'b1;
                                    end else begin
                                        check_pass <= 1'b0;
                                    end
                                end else begin
                                    check_pass <= 1'b0;
                                end
                            end else begin
                                check_pass <= 1'b0;
                            end
                        end else begin
                            // Both dx and dy non-zero
                            // Check if (a - xi) % dx == 0 AND (b - yi) % dy == 0
                            temp_div_a <= diff_a / dx;
                            temp_div_b <= diff_b / dy;
                            rem_a <= diff_a % dx;
                            rem_b <= diff_b % dy;
                            
                            if ((diff_a % dx == 0) && (diff_b % dy == 0)) begin
                                // Check if quotients are equal
                                if (temp_div_a == temp_div_b) begin
                                    // Check if quotient is non-negative
                                    if (temp_div_a >= 0) begin
                                        check_pass <= 1'b1;
                                    end else begin
                                        check_pass <= 1'b0;
                                    end
                                end else begin
                                    check_pass <= 1'b0;
                                end
                            end else begin
                                check_pass <= 1'b0;
                            end
                        end
                        
                        check_idx <= check_idx + 5'd1;
                    end else begin
                        // All positions checked, no match found
                        check_pass <= 1'b0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= check_pass;
                    // Reset for next operation
                    cycle_count <= 7'd0;
                    idx <= 5'd0;
                    cmd_idx <= 5'd0;
                    check_idx <= 5'd0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PRECALC;
            end
            
            PRECALC: begin
                if (cmd_idx >= seq_len || cycle_count >= MAX_CYCLES) begin
                    next_state = CHECK;
                end else begin
                    next_state = PRECALC;
                end
            end
            
            CHECK: begin
                if ((check_idx > seq_len) || (check_pass) || (cycle_count >= MAX_CYCLES)) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule