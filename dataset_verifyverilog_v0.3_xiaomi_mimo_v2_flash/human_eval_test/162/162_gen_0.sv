module simple_hash (
    input clk,
    input rst_n,
    input start,
    input [7:0] chars [0:7],
    input [7:0] length,
    output reg [31:0] hash,
    output reg done,
    output reg is_empty
);

    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] CHECK_LEN  = 2'd1;
    localparam [1:0] PROCESSING = 2'd2;
    localparam [1:0] FINISH     = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] counter, next_counter;       // Iterates 0 to 7
    reg [31:0] hash_reg, next_hash_reg;    // Accumulator
    reg [7:0] current_char;                // Registered char for processing
    
    // Control signals
    wire processing_done;
    
    assign processing_done = (counter == 3'd7);

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 3'd0;
            hash_reg <= 32'd0;
            hash <= 32'd0;
            done <= 1'b0;
            is_empty <= 1'b0;
            current_char <= 8'd0;
        end else begin
            state <= next_state;
            counter <= next_counter;
            hash_reg <= next_hash_reg;
            
            // Output assignments registered
            hash <= next_hash_reg;
            
            // Char register updates only during processing
            if (state == PROCESSING) begin
                current_char <= chars[counter];
            end
            
            // Done and is_empty assertion
            if (state == FINISH) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
            
            if (state == CHECK_LEN && length == 8'd0) begin
                is_empty <= 1'b1;
            end else if (state == IDLE) begin
                is_empty <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_counter = counter;
        next_hash_reg = hash_reg;

        case (state)
            IDLE: begin
                next_counter = 3'd0;
                next_hash_reg = 32'd0;
                if (start) begin
                    next_state = CHECK_LEN;
                end
            end

            CHECK_LEN: begin
                if (length == 8'd0) begin
                    // Empty string case
                    next_state = FINISH;
                end else begin
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                // Update hash: hash = hash * 33 + char
                // hash * 33 = (hash << 5) + hash
                // Using registered char to match the prompt's 'char_in' cycle timing
                // For the first cycle (counter=0), current_char is uninitialized in @*, 
                // but will be valid when sequential block updates current_char.
                // To ensure comb logic is clean, we use chars[counter] directly or current_char.
                // Prompt implies sequential feed logic, so we use current_char.
                // However, to avoid X-prop on first cycle, we drive from array directly 
                // or rely on initialization. Let's use array access for comb logic safety.
                next_hash_reg = (hash_reg << 5) + hash_reg + chars[counter];
                
                if (processing_done) begin
                    next_counter = 3'd0;
                    next_state = FINISH;
                end else begin
                    next_counter = counter + 3'd1;
                    next_state = PROCESSING;
                end
            end

            FINISH: begin
                // Hold outputs, wait for start to go low or reset
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
                next_counter = 3'd0;
                next_hash_reg = 32'd0;
            end
        endcase
    end

endmodule