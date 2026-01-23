module optimized_blacklist (
    input clk,
    input rst_n,
    input start,
    input [7:0] addr_i [0:7],
    input [3:0] mask_i [0:7],
    input [7:0] sign_i,
    input [7:0] valid_i,
    output reg [7:0] result_addr [0:7],
    output reg [3:0] result_mask [0:7],
    output reg [3:0] result_count,
    output reg done
);

    // State machine definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Storage for parsed intervals
    reg [7:0] black_start [0:7];
    reg [7:0] black_end [0:7];
    reg [7:0] white_start [0:7];
    reg [7:0] white_end [0:7];
    reg [2:0] black_count;
    reg [2:0] white_count;
    
    // Temporary registers
    reg [2:0] idx;
    reg conflict;
    reg [2:0] i_reg;
    reg [2:0] j_reg;
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // State transition
    always @(*) begin
        case (state)
            IDLE: next_state = start ? PARSE : IDLE;
            PARSE: next_state = (idx == 3'd8) ? CHECK : PARSE;
            CHECK: next_state = conflict ? OUTPUT : COMPUTE;
            COMPUTE: next_state = OUTPUT;
            OUTPUT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            black_count <= 3'd0;
            white_count <= 3'd0;
            idx <= 3'd0;
            conflict <= 1'b0;
            result_count <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            // Initialize arrays
            for (integer init_idx = 0; init_idx < 8; init_idx = init_idx + 1) begin
                black_start[init_idx] <= 8'd0;
                black_end[init_idx] <= 8'd0;
                white_start[init_idx] <= 8'd0;
                white_end[init_idx] <= 8'd0;
                result_addr[init_idx] <= 8'd0;
                result_mask[init_idx] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 3'd0;
                    conflict <= 1'b0;
                    i_reg <= 3'd0;
                    j_reg <= 3'd0;
                    black_count <= 3'd0;
                    white_count <= 3'd0;
                    cycle_count <= 8'd0;
                end
                
                PARSE: begin
                    if (valid_i[idx]) begin
                        if (sign_i[idx] == 1'b0) begin // Black
                            if (black_count < 3'd8) begin
                                black_start[black_count] <= addr_i[idx] & (8'hFF << (8 - mask_i[idx]));
                                black_end[black_count] <= addr_i[idx] | (8'hFF >> mask_i[idx]);
                                black_count <= black_count + 3'd1;
                            end
                        end else begin // White
                            if (white_count < 3'd8) begin
                                white_start[white_count] <= addr_i[idx] & (8'hFF << (8 - mask_i[idx]));
                                white_end[white_count] <= addr_i[idx] | (8'hFF >> mask_i[idx]);
                                white_count <= white_count + 3'd1;
                            end
                        end
                    end
                    idx <= idx + 3'd1;
                end
                
                CHECK: begin
                    // Initialize check loop
                    if (i_reg == 3'd0 && j_reg == 3'd0) begin
                        conflict <= 1'b0;
                    end
                    
                    // Check for conflict (break early if found)
                    if (!conflict && (black_count > 0) && (white_count > 0) && 
                        (black_start[i_reg] <= white_end[j_reg]) && 
                        (black_end[i_reg] >= white_start[j_reg])) begin
                        conflict <= 1'b1;
                    end
                    
                    // Increment counters
                    if (j_reg + 3'd1 < white_count) begin
                        j_reg <= j_reg + 3'd1;
                    end else if (i_reg + 3'd1 < black_count) begin
                        j_reg <= 3'd0;
                        i_reg <= i_reg + 3'd1;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // If no conflict and has black intervals, output first black
                    if (!conflict && (black_count > 3'd0)) begin
                        result_addr[0] <= black_start[0];
                        result_mask[0] <= 8'd8 - (black_end[0] - black_start[0] + 8'd1);
                        result_count <= 4'd1;
                    end else if (!conflict) begin
                        // No black intervals, block everything
                        result_addr[0] <= 8'h00;
                        result_mask[0] <= 4'd0;
                        result_count <= 4'd1;
                    end else begin
                        // Conflict detected
                        result_addr[0] <= 8'h00;
                        result_mask[0] <= 4'd0;
                        result_count <= 4'd0;
                    end
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        done <= 1'b1;
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule