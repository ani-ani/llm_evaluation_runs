module flip_case (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_index,
    input valid_in,
    output reg [7:0] char_out,
    output reg [3:0] char_index_out,
    output reg valid_out,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] count, next_count;
    
    // Internal control signals
    wire is_upper;
    wire is_lower;
    wire is_alpha;
    wire [7:0] flipped_char;

    // Character classification
    // ASCII: 'A'=0x41, 'Z'=0x5A, 'a'=0x61, 'z'=0x7A
    assign is_upper = (char_in >= 8'h41) && (char_in <= 8'h5A);
    assign is_lower = (char_in >= 8'h61) && (char_in <= 8'h7A);
    assign is_alpha = is_upper || is_lower;

    // Flip case by toggling bit 5 (0x20)
    assign flipped_char = char_in ^ 8'h20;

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
            end
            PROCESSING: begin
                // Process 16 characters (indices 0 to 15)
                if (valid_in && (char_index == 4'd15))
                    next_state = DONE;
            end
            DONE: begin
                // Stay in DONE until reset
            end
            default: next_state = IDLE;
        endcase
    end

    // Counter logic
    always @(*) begin
        next_count = count;
        if (state == IDLE && start) begin
            next_count = 4'd0;
        end else if (state == PROCESSING && valid_in) begin
            next_count = count + 1'b1;
        end
    end

    // Output logic
    always @(*) begin
        // Default outputs
        char_out = 8'b0;
        char_index_out = 4'b0;
        valid_out = 1'b0;
        done = 1'b0;

        case (state)
            PROCESSING: begin
                if (valid_in) begin
                    char_index_out = char_index;
                    if (is_alpha) begin
                        char_out = flipped_char;
                    end else begin
                        char_out = char_in;
                    end
                    valid_out = 1'b1;
                end
            end
            DONE: begin
                done = 1'b1;
            end
            default: begin
                // IDLE state outputs remain default
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'b0;
        end else begin
            state <= next_state;
            count <= next_count;
        end
    end

endmodule