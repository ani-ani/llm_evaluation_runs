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

    // Internal state machine
    reg [2:0] state;
    reg [2:0] next_state;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    
    // Storage for parsed intervals
    reg [7:0] black_start [0:7];
    reg [7:0] black_end [0:7];
    reg [7:0] white_start [0:7];
    reg [7:0] white_end [0:7];
    reg [2:0] black_count;
    reg [2:0] white_count;
    
    // Temporary registers
    reg [7:0] temp_start;
    reg [7:0] temp_end;
    reg [2:0] idx;
    reg conflict;
    
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
            PARSE: next_state = (idx == 8) ? CHECK : PARSE;
            CHECK: next_state = conflict ? OUTPUT : COMPUTE;
            COMPUTE: next_state = OUTPUT;
            OUTPUT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            black_count <= 3'd0;
            white_count <= 3'd0;
            idx <= 3'd0;
            conflict <= 1'b0;
            result_count <= 3'd0;
            done <= 1'b0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                black_start[i] <= 8'd0;
                black_end[i] <= 8'd0;
                white_start[i] <= 8'd0;
                white_end[i] <= 8'd0;
                result_addr[i] <= 8'd0;
                result_mask[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 3'd0;
                    conflict <= 1'b0;
                end
                
                PARSE: begin
                    if (valid_i[idx]) begin
                        // Parse subnet: a.b.c.d/x format simplified
                        // For 8-bit address: assume /0 to /8
                        if (sign_i[idx] == 8'd0) begin // Black
                            black_start[black_count] <= addr_i[idx] & (8'hFF << (8 - mask_i[idx]));
                            black_end[black_count] <= addr_i[idx] | (8'hFF >> mask_i[idx]);
                            black_count <= black_count + 3'd1;
                        end else begin // White
                            white_start[white_count] <= addr_i[idx] & (8'hFF << (8 - mask_i[idx]));
                            white_end[white_count] <= addr_i[idx] | (8'hFF >> mask_i[idx]);
                            white_count <= white_count + 3'd1;
                        end
                    end
                    idx <= idx + 3'd1;
                end
                
                CHECK: begin
                    // Simple conflict check: if any black interval overlaps any white interval
                    if (black_count > 3'd0 && white_count > 3'd0) begin
                        integer i, j;
                        for (i = 0; i < black_count; i = i + 1) begin
                            for (j = 0; j < white_count; j = j + 1) begin
                                if (black_start[i] <= white_end[j] && black_end[i] >= white_start[j]) begin
                                    conflict <= 1'b1;
                                end
                            end
                        end
                    end
                end
                
                COMPUTE: begin
                    // Simplified: output the first black interval if no conflict
                    if (!conflict && black_count > 3'd0) begin
                        result_addr[0] <= black_start[0];
                        result_mask[0] <= 8 - (black_end[0] - black_start[0] + 1);
                        result_count <= 3'd1;
                    end else if (!conflict) begin
                        // No black intervals, block everything
                        result_addr[0] <= 8'h00;
                        result_mask[0] <= 4'd0;
                        result_count <= 3'd1;
                    end
                    done <= 1'b1;
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule