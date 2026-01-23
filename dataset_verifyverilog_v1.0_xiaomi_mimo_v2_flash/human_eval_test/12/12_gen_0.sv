module longest_string(
    input clk,
    input rst_n,
    input start,
    input [7:0] strings [0:3][0:7],
    input [1:0] count,
    output reg [2:0] index,
    output reg valid
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LENGTH_CHECK = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] current_idx;
    reg [2:0] max_idx;
    reg [3:0] max_len;
    reg [3:0] current_len;
    reg [2:0] char_idx;
    reg [7:0] current_char;
    reg [1:0] count_reg;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15; // Enough for 4 strings * 8 chars

    // Combinational logic to access string array
    reg [7:0] current_string [0:7];
    integer i;
    always @(*) begin
        case (current_idx)
            3'd0: begin
                for (i = 0; i < 8; i = i + 1) begin
                    current_string[i] = strings[0][i];
                end
            end
            3'd1: begin
                for (i = 0; i < 8; i = i + 1) begin
                    current_string[i] = strings[1][i];
                end
            end
            3'd2: begin
                for (i = 0; i < 8; i = i + 1) begin
                    current_string[i] = strings[2][i];
                end
            end
            3'd3: begin
                for (i = 0; i < 8; i = i + 1) begin
                    current_string[i] = strings[3][i];
                end
            end
            default: begin
                for (i = 0; i < 8; i = i + 1) begin
                    current_string[i] = 8'd0;
                end
            end
        endcase
        current_char = current_string[char_idx];
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = LENGTH_CHECK;
            end
            LENGTH_CHECK: begin
                if (count_reg == 4'd0) begin
                    next_state = DONE;
                end else if (current_idx >= count_reg) begin
                    next_state = DONE;
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            valid <= 1'b0;
            current_idx <= 3'd0;
            max_idx <= 3'd0;
            max_len <= 4'd0;
            current_len <= 4'd0;
            char_idx <= 3'd0;
            count_reg <= 2'd0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    if (start) begin
                        current_idx <= 3'd0;
                        max_idx <= 3'd0;
                        max_len <= 4'd0;
                        current_len <= 4'd0;
                        char_idx <= 3'd0;
                        count_reg <= count;
                        cycle_count <= 4'd0;
                    end
                end
                
                LENGTH_CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (count_reg == 4'd0) begin
                        // No valid strings
                        index <= 3'd0;
                    end else if (current_idx < count_reg) begin
                        // Count current string length
                        if (char_idx < 3'd8) begin
                            if (current_char != 8'd0) begin
                                current_len <= current_len + 4'd1;
                            end
                            char_idx <= char_idx + 3'd1;
                        end else begin
                            // Finished current string
                            char_idx <= 3'd0;
                            
                            // Check if this is the longest
                            if (current_len > max_len) begin
                                max_len <= current_len;
                                max_idx <= current_idx;
                            end
                            
                            // Reset for next string
                            current_len <= 4'd0;
                            current_idx <= current_idx + 3'd1;
                        end
                    end
                end
                
                DONE: begin
                    if (count_reg == 4'd0) begin
                        index <= 3'd0;
                    end else begin
                        index <= max_idx;
                    end
                    valid <= 1'b1;
                end
            endcase
        end
    end

endmodule