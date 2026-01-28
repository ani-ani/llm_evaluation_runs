module adverb_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [127:0] data,
    output reg [3:0] start_pos,
    output reg [3:0] end_pos,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCANNING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] current_pos;
    reg [7:0] current_char, next_char;
    reg found;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd32;

    // Check if character is alphabetic (a-z or A-Z)
    function is_alphabetic;
        input [7:0] c;
        begin
            is_alphabetic = ((c >= 8'd65 && c <= 8'd90) || (c >= 8'd97 && c <= 8'd122));
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_pos <= 4'd0;
            start_pos <= 4'd0;
            end_pos <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            found <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCANNING;
                    current_pos = 4'd0;
                    found = 1'b0;
                    valid = 1'b0;
                    cycle_count = 4'd0;
                end
            end

            SCANNING: begin
                if (found || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = SCANNING;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_pos <= 4'd0;
            cycle_count <= 4'd0;
        end else if (state == SCANNING) begin
            cycle_count <= cycle_count + 4'd1;
            
            // Get current and next characters
            current_char = data[(current_pos * 8) +: 8];
            next_char = data[((current_pos + 1) * 8) +: 8];

            // Check for "ly" pattern with alphabetic character before
            if (current_pos > 4'd0 && current_pos < len - 4'd1) begin
                reg [7:0] prev_char = data[((current_pos - 1) * 8) +: 8];
                if (current_char == 8'd108 && next_char == 8'd121 && is_alphabetic(prev_char)) begin
                    found = 1'b1;
                    start_pos = current_pos - 4'd1;
                    end_pos = current_pos + 4'd1;
                    valid = 1'b1;
                end
            end

            // Move to next position
            if (!found) begin
                current_pos <= current_pos + 4'd1;
            end
        end
    end

    // Done signal generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            done <= (state == DONE_STATE);
        end
    end

endmodule