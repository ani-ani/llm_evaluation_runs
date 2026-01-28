module TreasureMap(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg [15:0] result,
    output reg result_valid,
    output reg done,
    output reg failure
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Counters and registers
    reg signed [31:0] balance;
    reg [3:0] hash_count;
    reg [3:0] last_hash_pos;
    reg [3:0] current_hash_idx;
    reg [3:0] hash_outputs [0:15];
    reg [7:0] char_reg;
    reg char_valid;

    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            balance <= 32'd0;
            hash_count <= 4'd0;
            last_hash_pos <= 4'd0;
            current_hash_idx <= 4'd0;
            result <= 16'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            failure <= 1'b0;
            cycle_count <= 8'd0;
            char_reg <= 8'd0;
            char_valid <= 1'b0;
            
            // Initialize hash_outputs array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                hash_outputs[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            // Process character if valid
            if (valid_in) begin
                char_reg <= char_in;
                char_valid <= 1'b1;
            end else if (state == PROCESS) begin
                char_valid <= 1'b0;
            end
            
            // State machine
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    failure <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        next_state <= PROCESS;
                        balance <= 32'd0;
                        hash_count <= 4'd0;
                        last_hash_pos <= 4'd0;
                        current_hash_idx <= 4'd0;
                        
                        // Reset hash_outputs
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            hash_outputs[i] <= 4'd0;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (char_valid) begin
                        case (char_reg)
                            8'd40: balance <= balance + 32'd1;  // '('
                            8'd41: balance <= balance - 32'd1;  // ')'
                            8'd35: begin  // '#'
                                if (hash_count < 4'd16) begin
                                    hash_outputs[hash_count] <= 4'd1;
                                    last_hash_pos <= hash_count;
                                    hash_count <= hash_count + 4'd1;
                                    balance <= balance - 32'd1;
                                end else begin
                                    failure <= 1'b1;
                                    next_state <= DONE_STATE;
                                end
                            end
                            default: ;  // Ignore other characters
                        endcase
                        
                        char_valid <= 1'b0;
                        
                        // Check for failure
                        if (balance < 32'd0) begin
                            failure <= 1'b1;
                            next_state <= DONE_STATE;
                        end
                    end
                    
                    // Check if processing is complete
                    if (!valid_in && !char_valid) begin
                        if (failure) begin
                            next_state <= DONE_STATE;
                        end else begin
                            // Final assignment
                            reg signed [31:0] remaining;
                            remaining = balance + 32'd1;
                            
                            if (remaining > 32'd0 && remaining <= 16'd15) begin
                                hash_outputs[last_hash_pos] <= remaining[3:0];
                                next_state <= OUTPUT;
                                current_hash_idx <= 4'd0;
                            end else begin
                                failure <= 1'b1;
                                next_state <= DONE_STATE;
                            end
                        end
                    end else if (cycle_count >= MAX_CYCLES) begin
                        failure <= 1'b1;
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= PROCESS;
                    end
                end

                OUTPUT: begin
                    result_valid <= 1'b0;
                    
                    if (current_hash_idx < hash_count) begin
                        result <= {12'd0, hash_outputs[current_hash_idx]};
                        result_valid <= 1'b1;
                        current_hash_idx <= current_hash_idx + 4'd1;
                        next_state <= OUTPUT;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result_valid <= 1'b0;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule