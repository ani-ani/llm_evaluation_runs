module tree_pattern_sum (
    input clk,
    input rst_n,
    input start,
    input [127:0] pattern_data,
    input [3:0] pattern_len,
    output reg [63:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD = 3'd1;
localparam [2:0] PROCESS = 3'd2;
localparam [2:0] FINISH = 3'd3;

reg [2:0] state, next_state;
reg [3:0] index, next_index;
reg [63:0] sum, next_sum;
reg [63:0] count, next_count;
reg [7:0] char, next_char;
reg [2:0] cycle_counter, next_cycle_counter;

// Combinatorial logic for processing
reg [63:0] new_sum, new_count;
always @(*) begin
    new_sum = sum;
    new_count = count;
    
    case (char)
        8'h4C: begin // 'L'
            new_sum = (sum << 1); // 2*sum
            new_count = count + 64'd1;
        end
        8'h52: begin // 'R'
            new_sum = (sum << 1) + 64'd1; // 2*sum + 1
            new_count = count + 64'd1;
        end
        8'h50: begin // 'P'
            new_sum = sum;
            new_count = count + 64'd1;
        end
        8'h2A: begin // '*'
            new_sum = (sum << 1) + count; // 2*sum + count
            new_count = (count << 1) + count; // 3*count
        end
        default: begin
            new_sum = sum;
            new_count = count;
        end
    endcase
end

// State transitions
always @(*) begin
    next_state = state;
    next_index = index;
    next_sum = sum;
    next_count = count;
    next_char = char;
    next_cycle_counter = cycle_counter;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = LOAD;
                next_index = 4'd0;
                next_sum = 64'd0;
                next_count = 64'd1;
                next_cycle_counter = 3'd0;
            end
        end
        
        LOAD: begin
            if (index < pattern_len) begin
                // Extract character from packed pattern_data
                case (index)
                    4'd0: next_char = pattern_data[7:0];
                    4'd1: next_char = pattern_data[15:8];
                    4'd2: next_char = pattern_data[23:16];
                    4'd3: next_char = pattern_data[31:24];
                    4'd4: next_char = pattern_data[39:32];
                    4'd5: next_char = pattern_data[47:40];
                    4'd6: next_char = pattern_data[55:48];
                    4'd7: next_char = pattern_data[63:56];
                    4'd8: next_char = pattern_data[71:64];
                    4'd9: next_char = pattern_data[79:72];
                    4'd10: next_char = pattern_data[87:80];
                    4'd11: next_char = pattern_data[95:88];
                    4'd12: next_char = pattern_data[103:96];
                    4'd13: next_char = pattern_data[111:104];
                    4'd14: next_char = pattern_data[119:112];
                    4'd15: next_char = pattern_data[127:120];
                    default: next_char = 8'h00;
                endcase
                next_state = PROCESS;
            end else begin
                next_state = FINISH;
            end
        end
        
        PROCESS: begin
            // Process one character per cycle (comb logic applied)
            next_sum = new_sum;
            next_count = new_count;
            next_index = index + 4'd1;
            next_state = LOAD;
        end
        
        FINISH: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        index <= 4'd0;
        sum <= 64'd0;
        count <= 64'd0;
        char <= 8'h00;
        cycle_counter <= 3'd0;
        result <= 64'd0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        index <= next_index;
        sum <= next_sum;
        count <= next_count;
        char <= next_char;
        cycle_counter <= next_cycle_counter;
        
        // Output logic
        done <= 1'b0;
        if (state == FINISH && next_state == IDLE) begin
            result <= sum;
            done <= 1'b1;
        end
    end
end

endmodule