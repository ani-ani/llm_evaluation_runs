module tuple_parser (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] tuple_str,
    output reg [2:0][7:0] result,
    output reg done,
    output reg error
);

    // State Encoding
    localparam IDLE        = 4'b0000;
    localparam PARSE_OPEN  = 4'b0001;
    localparam PARSE_NUM1  = 4'b0010;
    localparam PARSE_SEP1  = 4'b0011;
    localparam PARSE_NUM2  = 4'b0100;
    localparam PARSE_SEP2  = 4'b0101;
    localparam PARSE_NUM3  = 4'b0110;
    localparam PARSE_CLOSE = 4'b0111;
    localparam DONE        = 4'b1000;
    localparam ERROR       = 4'b1001;

    reg [3:0] current_state, next_state;
    reg [2:0] pos_count, next_pos_count; // Character position index (0 to 7)
    reg [1:0] num_idx;                   // Index of the number being parsed (0, 1, 2)
    
    // Registers for current number being built
    reg [7:0] current_num, next_current_num;
    reg [1:0] digit_cnt, next_digit_cnt; // 0, 1, or 2 digits parsed for current number
    
    // Combinational logic for current character extraction
    wire [7:0] char;
    assign char = tuple_str[63:56]; // Get byte at current position (MSB)
    
    // Next State Logic
    always @(*) begin
        next_state = current_state;
        next_pos_count = pos_count;
        next_current_num = current_num;
        next_digit_cnt = digit_cnt;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PARSE_OPEN;
                    next_pos_count = 3'd0;
                    next_current_num = 8'd0;
                    next_digit_cnt = 2'd0;
                end
            end
            
            PARSE_OPEN: begin
                if (char != 8'h28) begin // '(' is 0x28
                    next_state = ERROR;
                end else begin
                    if (pos_count < 3'd7) begin
                        next_pos_count = pos_count + 1;
                        // Shift the register for next character access
                        // Note: In hardware, this implies the tuple_str input is static, 
                        // so we must simulate the shift by accessing the bit field directly based on pos_count.
                        // However, to make the state machine sequential, we rely on the bit slice logic.
                        next_state = PARSE_NUM1;
                    end else begin
                        next_state = ERROR;
                    end
                end
            end
            
            PARSE_NUM1: begin
                if (char >= 8'h30 && char <= 8'h39) begin // '0'-'9'
                    if (digit_cnt == 2'd2) next_state = ERROR; // Too many digits
                    else begin
                        next_current_num = current_num * 10 + (char - 8'h30);
                        next_digit_cnt = digit_cnt + 1;
                        if (pos_count < 3'd7) begin
                            next_pos_count = pos_count + 1;
                            // Check next char (need to look ahead or process next cycle)
                            // Since we only advance pos_count here, the check happens next cycle
                        end else begin
                            next_state = ERROR;
                        end
                    end
                end else if (char == 8'h2C) begin // ','
                    if (digit_cnt == 0) next_state = ERROR; // No digits parsed
                    else begin
                        result[0] = current_num; // Save result
                        next_current_num = 8'd0;
                        next_digit_cnt = 2'd0;
                        if (pos_count < 3'd7) begin
                            next_pos_count = pos_count + 1;
                            next_state = PARSE_NUM2;
                        end else next_state = ERROR;
                    end
                end else begin
                    next_state = ERROR;
                end
            end
            
            PARSE_NUM2: begin
                if (char >= 8'h30 && char <= 8'h39) begin
                    if (digit_cnt == 2'd2) next_state = ERROR;
                    else begin
                        next_current_num = current_num * 10 + (char - 8'h30);
                        next_digit_cnt = digit_cnt + 1;
                        if (pos_count < 3'd7) next_pos_count = pos_count + 1;
                        else next_state = ERROR;
                    end
                end else if (char == 8'h2C) begin
                    if (digit_cnt == 0) next_state = ERROR;
                    else begin
                        result[1] = current_num;
                        next_current_num = 8'd0;
                        next_digit_cnt = 2'd0;
                        if (pos_count < 3'd7) begin
                            next_pos_count = pos_count + 1;
                            next_state = PARSE_NUM3;
                        end else next_state = ERROR;
                    end
                end else next_state = ERROR;
            end
            
            PARSE_NUM3: begin
                if (char >= 8'h30 && char <= 8'h39) begin
                    if (digit_cnt == 2'd2) next_state = ERROR;
                    else begin
                        next_current_num = current_num * 10 + (char - 8'h30);
                        next_digit_cnt = digit_cnt + 1;
                        if (pos_count < 3'd7) next_pos_count = pos_count + 1;
                        else next_state = ERROR;
                    end
                end else if (char == 8'h29) begin // ')'
                    if (digit_cnt == 0) next_state = ERROR;
                    else begin
                        result[2] = current_num;
                        if (pos_count < 3'd7) begin
                            next_pos_count = pos_count + 1;
                            next_state = PARSE_CLOSE;
                        end else next_state = ERROR;
                    end
                end else next_state = ERROR;
            end
            
            PARSE_CLOSE: begin
                // Must be followed by padding (spaces)
                if (char != 8'h20) begin
                    next_state = ERROR;
                end else begin
                    if (pos_count < 3'd7) begin
                        next_pos_count = pos_count + 1;
                    end else begin
                        next_state = DONE;
                    end
                end
            end
            
            DONE: begin
                // Stay in DONE until reset
            end
            
            ERROR: begin
                // Stay in ERROR until reset
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            pos_count <= 3'd0;
            current_num <= 8'd0;
            digit_cnt <= 2'd0;
            done <= 1'b0;
            error <= 1'b0;
            result <= 24'd0;
        end else begin
            current_state <= next_state;
            pos_count <= next_pos_count;
            current_num <= next_current_num;
            digit_cnt <= next_digit_cnt;

            // Handle output signals
            if (next_state == IDLE && start) begin
                done <= 1'b0;
                error <= 1'b0;
                result <= 24'd0;
            end
            
            // Save results when transitioning OUT of a number state due to separator
            if (current_state == PARSE_NUM1 && (next_state == PARSE_NUM2)) begin
                result[0] <= current_num;
            end
            if (current_state == PARSE_NUM2 && (next_state == PARSE_NUM3)) begin
                result[1] <= current_num;
            end
            if (current_state == PARSE_NUM3 && (next_state == PARSE_CLOSE)) begin
                result[2] <= current_num;
            end

            if (next_state == DONE) done <= 1'b1;
            if (next_state == ERROR) error <= 1'b1;
        end
    end

    // The state machine defined above relies on pos_count to drive the selection of bits from tuple_str.
    // However, standard Verilog lacks dynamic bit slicing by variable index in synthesis for this specific 'shift register' behavior.
    // To fix this for synthesis, we use a Multi-Bit Mux structure or rewrite the logic to be fully sequential.
    
    // Rewriting the character extraction logic to be robust:
    // We will extract the byte based on pos_count.
    wire [7:0] current_char;
    
    assign current_char = 
        (pos_count == 3'd0) ? tuple_str[63:56] :
        (pos_count == 3'd1) ? tuple_str[55:48] :
        (pos_count == 3'd2) ? tuple_str[47:40] :
        (pos_count == 3'd3) ? tuple_str[39:32] :
        (pos_count == 3'd4) ? tuple_str[31:24] :
        (pos_count == 3'd5) ? tuple_str[23:16] :
        (pos_count == 3'd6) ? tuple_str[15:8]  :
                              tuple_str[7:0];

    // Re-evaluate state transitions using the resolved current_char
    // We must override the combinational block to ensure correct character usage
    reg [3:0] state_next;
    reg [2:0] pos_next;
    reg [7:0] num_next;
    reg [1:0] cnt_next;

    always @(*) begin
        state_next = current_state;
        pos_next = pos_count;
        num_next = current_num;
        cnt_next = digit_cnt;

        case (current_state)
            IDLE: begin
                if (start) begin
                    state_next = PARSE_OPEN;
                    pos_next = 3'd0;
                    num_next = 8'd0;
                    cnt_next = 2'd0;
                end
            end

            PARSE_OPEN: begin
                if (current_char != 8'h28) state_next = ERROR;
                else begin
                    if (pos_count < 3'd7) begin
                        pos_next = pos_count + 1;
                        state_next = PARSE_NUM1;
                    end else state_next = ERROR;
                end
            end

            PARSE_NUM1, PARSE_NUM2, PARSE_NUM3: begin
                if (current_char >= 8'h30 && current_char <= 8'h39) begin
                    if (digit_cnt == 2'd2) state_next = ERROR;
                    else begin
                        num_next = current_num * 10 + (current_char - 8'h30);
                        cnt_next = digit_cnt + 1;
                        if (pos_count < 3'd7) pos_next = pos_count + 1;
                        else state_next = ERROR;
                    end
                end else if (current_char == 8'h2C) begin // Comma
                    if (digit_cnt == 0) state_next = ERROR;
                    else begin
                        // Logic to advance state based on which number we just finished
                        if (current_state == PARSE_NUM1) state_next = PARSE_NUM2;
                        else if (current_state == PARSE_NUM2) state_next = PARSE_NUM3;
                        else state_next = ERROR; // Cannot have comma after Num3
                        
                        // Since we are assigning to registers, we must handle the 'save result' logic here? 
                        // No, we can only update 'result' register in sequential logic.
                        // But we need to pass the value. We will use a temporary storage or update sequentially.
                        // To ensure the result is saved, we'll set a flag or just update the register in the sequential block.
                        // However, Verilog logic usually updates the register at the end of the block.
                        // We will rely on the sequential block to save the value when the state transitions away from a NUM state with valid digits.
                        // EXCEPT: We need to reset num and cnt for the NEXT number.
                        num_next = 8'd0;
                        cnt_next = 2'd0;
                        if (pos_count < 3'd7) pos_next = pos_count + 1;
                        else state_next = ERROR;
                    end
                end else if (current_char == 8'h29 && current_state == PARSE_NUM3) begin
                    // Special case for the end of the third number
                    if (digit_cnt == 0) state_next = ERROR;
                    else begin
                        if (pos_count < 3'd7) begin
                            pos_next = pos_count + 1;
                            state_next = PARSE_CLOSE;
                        end else state_next = ERROR;
                    end
                end else begin
                    state_next = ERROR;
                end
            end

            PARSE_CLOSE: begin
                if (current_char != 8'h20) state_next = ERROR;
                else begin
                    if (pos_count < 3'd7) begin
                        pos_next = pos_count + 1;
                    end else begin
                        state_next = DONE;
                    end
                end
            end

            DONE, ERROR: begin
                // Stay here until reset
            end
            
            default: state_next = IDLE;
        endcase
    end

    // Sequential Logic and Output Assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            pos_count <= 3'd0;
            current_num <= 8'd0;
            digit_cnt <= 2'd0;
            done <= 1'b0;
            error <= 1'b0;
            result <= 24'd0;
        end else begin
            current_state <= state_next;
            pos_count <= pos_next;
            current_num <= num_next;
            digit_cnt <= cnt_next;

            // Handle output signals
            if (state_next == IDLE && start) begin
                done <= 1'b0;
                error <= 1'b0;
                result <= 24'd0;
            end
            
            // Save results when transitioning OUT of a number state due to separator
            if (current_state == PARSE_NUM1 && (state_next == PARSE_NUM2)) begin
                result[0] <= current_num;
            end
            if (current_state == PARSE_NUM2 && (state_next == PARSE_NUM3)) begin
                result[1] <= current_num;
            end
            if (current_state == PARSE_NUM3 && (state_next == PARSE_CLOSE)) begin
                result[2] <= current_num;
            end

            if (state_next == DONE) done <= 1'b1;
            if (state_next == ERROR) error <= 1'b1;
        end
    end

endmodule