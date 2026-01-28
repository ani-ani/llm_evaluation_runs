module DistanceSum (
    input clk,
    input rst_n,
    input start,
    input [3:0] A3, A2, A1, A0,
    input [3:0] B3, B2, B1, B0,
    input [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CONVERT_A   = 3'd1;
    localparam [2:0] CONVERT_B   = 3'd2;
    localparam [2:0] INIT_OUTER  = 3'd3;
    localparam [2:0] INNER_LOOP  = 3'd4;
    localparam [2:0] COMPUTE_DIST= 3'd5;
    localparam [2:0] ACCUMULATE  = 3'd6;
    localparam [2:0] FINISH      = 3'd7;

    // Modulus constant
    localparam [31:0] MOD = 32'd1000000007;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] i_val, j_val;  // Current numbers in range
    reg [15:0] A_int, B_int;  // Integer values of A and B
    reg [3:0] i_idx, j_idx;   // Loop indices
    reg [31:0] sum;
    reg [15:0] temp_i, temp_j; // For digit extraction
    reg [3:0] digit_i [0:3];   // Digits of i
    reg [3:0] digit_j [0:3];   // Digits of j
    reg [3:0] digit_diff [0:3]; // Absolute differences
    reg [7:0] cycle_count;     // Safety counter
    reg [1:0] digit_idx;       // For digit extraction loop
    reg [7:0] dist_calc;       // Distance calculation accumulator
    reg [31:0] temp_sum;       // Temporary sum for modulo
    reg [1:0] conv_step;       // Conversion step counter
    reg [3:0] len_reg;         // Registered len

    // Integer conversion logic
    function automatic [15:0] convert_to_int;
        input [3:0] d3, d2, d1, d0;
        input [3:0] length;
        reg [15:0] val;
        begin
            val = 16'd0;
            if (length > 3'd0) val = val + d3;
            if (length > 3'd1) val = val * 10 + d2;
            if (length > 3'd2) val = val * 10 + d1;
            if (length > 3'd3) val = val * 10 + d0;
            convert_to_int = val;
        end
    endfunction

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i_val <= 16'd0;
            j_val <= 16'd0;
            A_int <= 16'd0;
            B_int <= 16'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            sum <= 32'd0;
            temp_i <= 16'd0;
            temp_j <= 16'd0;
            cycle_count <= 8'd0;
            digit_idx <= 2'd0;
            dist_calc <= 8'd0;
            temp_sum <= 32'd0;
            conv_step <= 2'd0;
            len_reg <= 4'd0;
            digit_i[0] <= 4'd0;
            digit_i[1] <= 4'd0;
            digit_i[2] <= 4'd0;
            digit_i[3] <= 4'd0;
            digit_j[0] <= 4'd0;
            digit_j[1] <= 4'd0;
            digit_j[2] <= 4'd0;
            digit_j[3] <= 4'd0;
            digit_diff[0] <= 4'd0;
            digit_diff[1] <= 4'd0;
            digit_diff[2] <= 4'd0;
            digit_diff[3] <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        len_reg <= len;
                        conv_step <= 2'd0;
                    end
                end

                CONVERT_A: begin
                    // Convert A to integer
                    if (conv_step == 2'd0) begin
                        A_int <= convert_to_int(A3, A2, A1, A0, len_reg);
                        conv_step <= conv_step + 2'd1;
                    end
                end

                CONVERT_B: begin
                    // Convert B to integer
                    if (conv_step == 2'd1) begin
                        B_int <= convert_to_int(B3, B2, B1, B0, len_reg);
                        conv_step <= conv_step + 2'd1;
                    end
                end

                INIT_OUTER: begin
                    sum <= 32'd0;
                    i_idx <= 4'd0;
                    cycle_count <= 8'd0;
                    i_val <= A_int;
                end

                INNER_LOOP: begin
                    if (i_idx < (B_int - A_int)) begin
                        j_val <= i_val + 16'd1;
                        j_idx <= i_idx + 4'd1;
                        cycle_count <= cycle_count + 8'd1;
                    end
                end

                COMPUTE_DIST: begin
                    // Extract digits
                    digit_i[0] <= i_val % 10;
                    digit_i[1] <= (i_val / 10) % 10;
                    digit_i[2] <= (i_val / 100) % 10;
                    digit_i[3] <= (i_val / 1000) % 10;
                    
                    digit_j[0] <= j_val % 10;
                    digit_j[1] <= (j_val / 10) % 10;
                    digit_j[2] <= (j_val / 100) % 10;
                    digit_j[3] <= (j_val / 1000) % 10;
                    
                    digit_idx <= 2'd0;
                    dist_calc <= 8'd0;
                end

                ACCUMULATE: begin
                    // Compute absolute differences
                    if (digit_idx == 2'd0) begin
                        if (digit_i[0] > digit_j[0])
                            digit_diff[0] <= digit_i[0] - digit_j[0];
                        else
                            digit_diff[0] <= digit_j[0] - digit_i[0];
                        digit_idx <= digit_idx + 2'd1;
                    end else if (digit_idx == 2'd1) begin
                        if (digit_i[1] > digit_j[1])
                            digit_diff[1] <= digit_i[1] - digit_j[1];
                        else
                            digit_diff[1] <= digit_j[1] - digit_i[1];
                        digit_idx <= digit_idx + 2'd1;
                    end else if (digit_idx == 2'd2) begin
                        if (digit_i[2] > digit_j[2])
                            digit_diff[2] <= digit_i[2] - digit_j[2];
                        else
                            digit_diff[2] <= digit_j[2] - digit_i[2];
                        digit_idx <= digit_idx + 2'd1;
                    end else if (digit_idx == 2'd3) begin
                        if (digit_i[3] > digit_j[3])
                            digit_diff[3] <= digit_i[3] - digit_j[3];
                        else
                            digit_diff[3] <= digit_j[3] - digit_i[3];
                        
                        // Sum all differences
                        dist_calc <= digit_diff[0] + digit_diff[1] + digit_diff[2] + 
                                    (digit_i[3] > digit_j[3] ? (digit_i[3] - digit_j[3]) : (digit_j[3] - digit_i[3]));
                        
                        // Add to total sum with modulo
                        temp_sum <= sum + dist_calc;
                        if (temp_sum >= MOD)
                            temp_sum <= temp_sum - MOD;
                    end
                end

                FINISH: begin
                    result <= sum;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = CONVERT_A;
            end

            CONVERT_A: begin
                next_state = CONVERT_B;
            end

            CONVERT_B: begin
                next_state = INIT_OUTER;
            end

            INIT_OUTER: begin
                if (A_int < B_int)
                    next_state = INNER_LOOP;
                else if (A_int == B_int)
                    next_state = FINISH;
            end

            INNER_LOOP: begin
                if (i_idx < (B_int - A_int))
                    next_state = COMPUTE_DIST;
                else
                    next_state = FINISH;
            end

            COMPUTE_DIST: begin
                next_state = ACCUMULATE;
            end

            ACCUMULATE: begin
                if (digit_idx == 2'd3) begin
                    // After adding distance to sum
                    if ((i_val + 16'd1) <= B_int) begin
                        next_state = INNER_LOOP;
                    end else begin
                        next_state = FINISH;
                    end
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule