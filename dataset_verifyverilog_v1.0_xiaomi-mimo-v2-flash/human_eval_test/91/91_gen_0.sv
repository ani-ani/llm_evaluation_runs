module SentenceCounter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1023:0] str_input,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] CHECK_CHAR = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [6:0] index;           // 0-127 for character positions
    reg [7:0] boredom_count;   // 0-127 counter
    reg [7:0] next_boredom_count;
    reg [6:0] next_index;
    reg done_next;
    reg [7:0] result_next;

    // ASCII constants
    localparam [7:0] ASCII_PERIOD = 8'h2E;  // '.'
    localparam [7:0] ASCII_QMARK  = 8'h3F;  // '?'
    localparam [7:0] ASCII_EXCLAM = 8'h21;  // '!'
    localparam [7:0] ASCII_I      = 8'h49;  // 'I'

    // Current character extraction (combinational)
    wire [7:0] current_char;
    assign current_char = str_input[(index*8)+7 : (index*8)];

    // Next character extraction (for CHECK_CHAR state)
    wire [7:0] next_char;
    assign next_char = str_input[((index+1)*8)+7 : ((index+1)*8)];

    // FSM next state and output logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_index = index;
        next_boredom_count = boredom_count;
        done_next = 1'b0;
        result_next = result;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCAN;
                    next_index = 7'd0;
                    next_boredom_count = 8'd0;
                end
            end

            SCAN: begin
                // Check if we've scanned all 128 characters
                if (index >= 7'd128) begin
                    next_state = COMPLETE;
                end else begin
                    // Check if current character is a delimiter
                    if ((current_char == ASCII_PERIOD) || 
                        (current_char == ASCII_QMARK) || 
                        (current_char == ASCII_EXCLAM)) begin
                        // Transition to CHECK_CHAR state
                        next_state = CHECK_CHAR;
                        // Keep index same for now, will check next char
                    end else begin
                        // Not a delimiter, continue scanning
                        next_index = index + 7'd1;
                    end
                end
            end

            CHECK_CHAR: begin
                // Check if next character is 'I' and we're not at end of string
                if (index < 7'd127 && next_char == ASCII_I) begin
                    next_boredom_count = boredom_count + 8'd1;
                end
                // Always move to next character and return to SCAN
                next_index = index + 7'd1;
                next_state = SCAN;
            end

            COMPLETE: begin
                done_next = 1'b1;
                result_next = boredom_count;
                // Remain in COMPLETE until reset or new start
                if (start) begin
                    next_state = SCAN;
                    next_index = 7'd0;
                    next_boredom_count = 8'd0;
                    done_next = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 7'd0;
            boredom_count <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            index <= next_index;
            boredom_count <= next_boredom_count;
            result <= result_next;
            done <= done_next;
        end
    end

endmodule