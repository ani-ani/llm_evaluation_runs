module swap_generator (
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    output reg valid,
    output reg [9:0] a_out,
    output reg [9:0] b_out,
    output reg out_valid,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK = 3'b001;
    localparam BLOCK = 3'b010;
    localparam CROSS = 3'b011;
    localparam DONE_STATE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // Counter registers
    reg [9:0] block_k; // Current block start index (0, 4, 8...)
    reg [2:0] swap_cnt; // 0-5 for internal swaps
    reg [2:0] cross_cnt; // 0-3 for cross swaps
    reg [9:0] n_reg;
    reg [9:0] max_k; // Last block start index
    reg mod1; // 1 if n % 4 == 1

    // Helper logic for max_k
    wire [9:0] max_k_wire = mod1 ? (n_reg - 5) : (n_reg - 4);

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CHECK : IDLE;
            
            CHECK: begin
                if (n_reg < 2) 
                    next_state = DONE_STATE;
                else if (mod1 || (n_reg[1:0] == 2'b00))
                    next_state = BLOCK;
                else
                    next_state = DONE_STATE;
            end

            BLOCK: begin
                if (swap_cnt < 3'd5)
                    next_state = BLOCK;
                else begin
                    // Finished internal swaps for this block
                    if (mod1)
                        next_state = CROSS;
                    else if (block_k < max_k_wire)
                        next_state = BLOCK;
                    else
                        next_state = DONE_STATE;
                end
            end

            CROSS: begin
                if (cross_cnt < 3'd3)
                    next_state = CROSS;
                else begin
                    // Finished cross swaps for this block
                    if (block_k < max_k_wire)
                        next_state = BLOCK;
                    else
                        next_state = DONE_STATE;
                end
            end

            DONE_STATE: next_state = DONE_STATE;

            default: next_state = IDLE;
        endcase
    end

    // Output Logic & Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            done <= 0;
            out_valid <= 0;
            a_out <= 0;
            b_out <= 0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    out_valid <= 0;
                    done <= 0;
                    if (start) begin
                        n_reg <= n;
                    end
                end

                CHECK: begin
                    // Check mod 4
                    if (n_reg[1:0] == 2'b00 || n_reg[1:0] == 2'b01) begin
                        valid <= 1;
                        mod1 <= (n_reg[1:0] == 2'b01);
                        // Initialize counters
                        block_k <= 0;
                        // Pre-calculate max_k to avoid complex arithmetic in other states
                        if (n_reg[1:0] == 2'b01) 
                            max_k <= n_reg - 5;
                        else 
                            max_k <= n_reg - 4;
                    end else begin
                        valid <= 0;
                        done <= 1;
                    end
                end

                BLOCK: begin
                    // Generate internal swaps based on swap_cnt
                    case (swap_cnt)
                        3'd0: begin // (k, k+2)
                            a_out <= block_k; b_out <= block_k + 2;
                        end
                        3'd1: begin // (k+1, k+3)
                            a_out <= block_k + 1; b_out <= block_k + 3;
                        end
                        3'd2: begin // (k, k+1)
                            a_out <= block_k; b_out <= block_k + 1;
                        end
                        3'd3: begin // (k+2, k+3)
                            a_out <= block_k + 2; b_out <= block_k + 3;
                        end
                        3'd4: begin // (k, k+3)
                            a_out <= block_k; b_out <= block_k + 3;
                        end
                        3'd5: begin // (k+1, k+2) - This state handles transition logic
                            a_out <= block_k + 1; b_out <= block_k + 2;
                        end
                    endcase
                    
                    out_valid <= 1;
                    
                    // Update counter for next cycle
                    if (swap_cnt < 3'd5)
                        swap_cnt <= swap_cnt + 1;
                    else begin
                        swap_cnt <= 0; // Reset for next block
                        if (!mod1 && block_k >= max_k) begin
                            // If not mod1 and this was last block, will go to DONE next cycle
                            // But we need to output the last valid pair now
                        end
                    end
                end

                CROSS: begin
                    // Generate (0, block_k + cross_cnt)
                    a_out <= 0;
                    b_out <= block_k + cross_cnt;
                    out_valid <= 1;

                    // Update counter
                    if (cross_cnt < 3'd3)
                        cross_cnt <= cross_cnt + 1;
                    else begin
                        cross_cnt <= 0;
                        // Move to next block
                        block_k <= block_k + 4;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    out_valid <= 0;
                end
            endcase
            
            // Special handling for state transitions involving block updates
            // These must happen after the outputs are generated
            if (state == BLOCK && next_state != BLOCK) begin
                // Transitioning out of BLOCK state
                if (mod1) begin
                    // Will enter CROSS, keep block_k same, swap_cnt already reset in BLOCK logic (if applicable)
                end else begin
                    // Must increment block_k here because BLOCK logic handles counter increment
                    // But block_k update needs to happen at the end of the cycle for next cycle's state
                    if (block_k < max_k) begin
                        block_k <= block_k + 4;
                    end
                end
            end
        end
    end

    // Fix the blocking assignments for non-blocking logic inside always block
    // Re-structuring the sequential logic to be strictly non-blocking
    
    // Corrected Sequential Block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            done <= 0;
            out_valid <= 0;
            a_out <= 0;
            b_out <= 0;
            swap_cnt <= 0;
            cross_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 0;
                    done <= 0;
                    if (start) begin
                        n_reg <= n;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    if (n_reg < 2) begin
                        valid <= 0;
                        done <= 1;
                        state <= DONE_STATE;
                    end else if (n_reg[1:0] == 2'b00 || n_reg[1:0] == 2'b01) begin
                        valid <= 1;
                        if (n_reg[1:0] == 2'b01) begin
                            mod1 <= 1;
                            max_k <= n_reg - 5;
                        end else begin
                            mod1 <= 0;
                            max_k <= n_reg - 4;
                        end
                        block_k <= 0;
                        swap_cnt <= 0;
                        cross_cnt <= 0;
                        state <= BLOCK;
                    end else begin
                        valid <= 0;
                        done <= 1;
                        state <= DONE_STATE;
                    end
                end

                BLOCK: begin
                    // Output
                    out_valid <= 1;
                    case (swap_cnt)
                        3'd0: {a_out, b_out} <= {block_k, block_k + 2};
                        3'd1: {a_out, b_out} <= {block_k + 1, block_k + 3};
                        3'd2: {a_out, b_out} <= {block_k, block_k + 1};
                        3'd3: {a_out, b_out} <= {block_k + 2, block_k + 3};
                        3'd4: {a_out, b_out} <= {block_k, block_k + 3};
                        3'd5: {a_out, b_out} <= {block_k + 1, block_k + 2};
                    endcase

                    // Next State Logic & Transition Actions
                    if (swap_cnt < 3'd5) begin
                        swap_cnt <= swap_cnt + 1;
                    end else begin
                        // Last swap done
                        if (mod1) begin
                            state <= CROSS;
                            cross_cnt <= 0;
                        end else begin
                            if (block_k < max_k) begin
                                block_k <= block_k + 4;
                                swap_cnt <= 0;
                                // Stay in BLOCK
                            end else begin
                                state <= DONE_STATE;
                            end
                        end
                    end
                end

                CROSS: begin
                    // Output
                    out_valid <= 1;
                    a_out <= 0;
                    b_out <= block_k + cross_cnt;

                    // Next State Logic & Transition Actions
                    if (cross_cnt < 3'd3) begin
                        cross_cnt <= cross_cnt + 1;
                    end else begin
                        // Last cross swap done
                        if (block_k < max_k) begin
                            block_k <= block_k + 4;
                            swap_cnt <= 0;
                            state <= BLOCK;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    out_valid <= 0;
                    // Stay here until reset
                end
            endcase
        end
    end

endmodule