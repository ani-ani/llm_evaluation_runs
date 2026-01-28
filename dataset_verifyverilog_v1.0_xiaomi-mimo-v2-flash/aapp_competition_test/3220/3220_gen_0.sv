module WizardDance (
    input clk,
    input rst_n,
    input start,
    input [3:0] p_0,
    input [3:0] p_1,
    input [3:0] p_2,
    input [3:0] p_3,
    input [3:0] p_4,
    input [3:0] p_5,
    input [3:0] p_6,
    input [3:0] p_7,
    output reg [63:0] result,
    output reg valid,
    output reg done
);

    // Constants
    localparam [2:0] N = 3'd8;
    localparam [7:0] MAX_MASK = 8'd255;
    localparam [7:0] ASCII_L = 8'd76;  // 'L'
    localparam [7:0] ASCII_R = 8'd82;  // 'R'
    localparam [7:0] ASCII_SPACE = 8'd32;

    // State Machine
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] ITERATE = 2'd1;
    localparam [1:0] CHECK = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] mask, next_mask;
    reg [7:0] best_mask, next_best_mask;
    reg found_valid, next_found_valid;
    
    // Collision check registers
    reg [2:0] pos [0:7];  // Unpacked array for positions
    reg [2:0] next_pos [0:7];
    reg [2:0] i, j;  // Loop counters
    reg collision, next_collision;
    reg [2:0] temp_pos_i, temp_pos_j;

    // Input buffer
    reg [3:0] p_buf [0:7];
    reg inputs_loaded;

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 8'd0;
            best_mask <= 8'd0;
            found_valid <= 1'b0;
            result <= 64'd0;
            valid <= 1'b0;
            done <= 1'b0;
            inputs_loaded <= 1'b0;
            collision <= 1'b0;
            for (k = 0; k < 8; k = k + 1) begin
                pos[k] <= 3'd0;
                p_buf[k] <= 4'd0;
            end
        end else begin
            state <= next_state;
            mask <= next_mask;
            best_mask <= next_best_mask;
            found_valid <= next_found_valid;
            collision <= next_collision;
            for (k = 0; k < 8; k = k + 1) begin
                pos[k] <= next_pos[k];
            end
            
            // Load inputs on start
            if (start && state == IDLE) begin
                p_buf[0] <= p_0;
                p_buf[1] <= p_1;
                p_buf[2] <= p_2;
                p_buf[3] <= p_3;
                p_buf[4] <= p_4;
                p_buf[5] <= p_5;
                p_buf[6] <= p_6;
                p_buf[7] <= p_7;
                inputs_loaded <= 1'b1;
            end else if (state != IDLE) begin
                inputs_loaded <= 1'b0;
            end

            // Generate result on DONE
            if (state == DONE_STATE) begin
                if (found_valid) begin
                    valid <= 1'b1;
                    // Pack result
                    result[7:0]   <= (best_mask[0]) ? ASCII_R : ASCII_L;
                    result[15:8]  <= (best_mask[1]) ? ASCII_R : ASCII_L;
                    result[23:16] <= (best_mask[2]) ? ASCII_R : ASCII_L;
                    result[31:24] <= (best_mask[3]) ? ASCII_R : ASCII_L;
                    result[39:32] <= (best_mask[4]) ? ASCII_R : ASCII_L;
                    result[47:40] <= (best_mask[5]) ? ASCII_R : ASCII_L;
                    result[55:48] <= (best_mask[6]) ? ASCII_R : ASCII_L;
                    result[63:56] <= (best_mask[7]) ? ASCII_R : ASCII_L;
                end else begin
                    valid <= 1'b0;
                    result <= 64'd0;  // Clear result if no solution
                end
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    always @(*) begin
        next_state = state;
        next_mask = mask;
        next_best_mask = best_mask;
        next_found_valid = found_valid;
        next_collision = collision;
        for (k = 0; k < 8; k = k + 1) begin
            next_pos[k] = pos[k];
        end

        case (state)
            IDLE: begin
                if (start && inputs_loaded) begin
                    next_state = ITERATE;
                    next_mask = 8'd0;
                    next_best_mask = 8'd0;
                    next_found_valid = 1'b0;
                    next_collision = 1'b0;
                end
            end

            ITERATE: begin
                // Calculate positions for current mask
                // Wizard 0
                if (mask[0]) next_pos[0] = (0 + p_buf[0]) % N;
                else next_pos[0] = (0 - p_buf[0]) % N;
                // Wizard 1
                if (mask[1]) next_pos[1] = (1 + p_buf[1]) % N;
                else next_pos[1] = (1 - p_buf[1]) % N;
                // Wizard 2
                if (mask[2]) next_pos[2] = (2 + p_buf[2]) % N;
                else next_pos[2] = (2 - p_buf[2]) % N;
                // Wizard 3
                if (mask[3]) next_pos[3] = (3 + p_buf[3]) % N;
                else next_pos[3] = (3 - p_buf[3]) % N;
                // Wizard 4
                if (mask[4]) next_pos[4] = (4 + p_buf[4]) % N;
                else next_pos[4] = (4 - p_buf[4]) % N;
                // Wizard 5
                if (mask[5]) next_pos[5] = (5 + p_buf[5]) % N;
                else next_pos[5] = (5 - p_buf[5]) % N;
                // Wizard 6
                if (mask[6]) next_pos[6] = (6 + p_buf[6]) % N;
                else next_pos[6] = (6 - p_buf[6]) % N;
                // Wizard 7
                if (mask[7]) next_pos[7] = (7 + p_buf[7]) % N;
                else next_pos[7] = (7 - p_buf[7]) % N;

                next_state = CHECK;
            end

            CHECK: begin
                // Check collisions
                next_collision = 1'b0;
                
                // Compare all pairs (i, j) where i < j
                // Using nested if statements instead of loops for combinational logic
                if (!next_collision && pos[0] == pos[1]) next_collision = 1'b1;
                if (!next_collision && pos[0] == pos[2]) next_collision = 1'b1;
                if (!next_collision && pos[0] == pos[3]) next_collision = 1'b1;
                if (!next_collision && pos[0] == pos[4]) next_collision = 1'b1;
                if (!next_collision && pos[0] == pos[5]) next_collision = 1'b1;
                if (!next_collision && pos[0] == pos[6]) next_collision = 1'b1;
                if (!next_collision && pos[0] == pos[7]) next_collision = 1'b1;
                
                if (!next_collision && pos[1] == pos[2]) next_collision = 1'b1;
                if (!next_collision && pos[1] == pos[3]) next_collision = 1'b1;
                if (!next_collision && pos[1] == pos[4]) next_collision = 1'b1;
                if (!next_collision && pos[1] == pos[5]) next_collision = 1'b1;
                if (!next_collision && pos[1] == pos[6]) next_collision = 1'b1;
                if (!next_collision && pos[1] == pos[7]) next_collision = 1'b1;

                if (!next_collision && pos[2] == pos[3]) next_collision = 1'b1;
                if (!next_collision && pos[2] == pos[4]) next_collision = 1'b1;
                if (!next_collision && pos[2] == pos[5]) next_collision = 1'b1;
                if (!next_collision && pos[2] == pos[6]) next_collision = 1'b1;
                if (!next_collision && pos[2] == pos[7]) next_collision = 1'b1;

                if (!next_collision && pos[3] == pos[4]) next_collision = 1'b1;
                if (!next_collision && pos[3] == pos[5]) next_collision = 1'b1;
                if (!next_collision && pos[3] == pos[6]) next_collision = 1'b1;
                if (!next_collision && pos[3] == pos[7]) next_collision = 1'b1;

                if (!next_collision && pos[4] == pos[5]) next_collision = 1'b1;
                if (!next_collision && pos[4] == pos[6]) next_collision = 1'b1;
                if (!next_collision && pos[4] == pos[7]) next_collision = 1'b1;

                if (!next_collision && pos[5] == pos[6]) next_collision = 1'b1;
                if (!next_collision && pos[5] == pos[7]) next_collision = 1'b1;

                if (!next_collision && pos[6] == pos[7]) next_collision = 1'b1;

                if (!next_collision) begin
                    // Valid solution found
                    if (!next_found_valid) begin
                        next_found_valid = 1'b1;
                        next_best_mask = mask;
                    end
                end

                // Check if last mask
                if (mask == MAX_MASK) begin
                    next_state = DONE_STATE;
                end else begin
                    next_mask = mask + 8'd1;
                    next_state = ITERATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule