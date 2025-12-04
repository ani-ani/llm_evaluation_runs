module word_splitter (
    input clk,
    input rst_n,
    input start,
    input [127:0] text_in,
    output reg [4:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] byte_index, next_byte_index;
    reg [4:0] splitter_count, next_splitter_count;
    reg [4:0] letter_count, next_letter_count;
    reg [4:0] next_result;
    reg next_done;

    // Sequential block: update registers on clock or reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            byte_index <= 0;
            splitter_count <= 0;
            letter_count <= 0;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            byte_index <= next_byte_index;
            splitter_count <= next_splitter_count;
            letter_count <= next_letter_count;
            result <= next_result;
            done <= next_done;
        end
    end

    // Combinational block: compute next state and outputs
    always_comb begin
        // Default values
        next_state = state;
        next_byte_index = byte_index;
        next_splitter_count = splitter_count;
        next_letter_count = letter_count;
        next_result = result;
        next_done = 0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    next_byte_index = 0;
                    next_splitter_count = 0;
                    next_letter_count = 0;
                end
            end

            PROCESS: begin
                // Calculate the current byte from text_in using the byte_index
                integer addr;
                addr = (15 - byte_index) * 8;
                reg [7:0] current_byte;
                current_byte = text_in[addr +: 8];

                // Update the splitter count
                if (current_byte == 8'h20 || current_byte == 8'h2C) begin
                    next_splitter_count = splitter_count + 1;
                end else begin
                    next_splitter_count = splitter_count;
                end

                // Update the letter count for odd-positioned lowercase letters
                if (current_byte >= 8'h61 && current_byte <= 8'h7A) begin
                    // Check the least significant bit: if it's 0, then (current_byte - 8'h61) is odd
                    if (current_byte[0] == 1'b0) begin
                        next_letter_count = letter_count + 1;
                    end else begin
                        next_letter_count = letter_count;
                    end
                end else begin
                    next_letter_count = letter_count;
                end

                // If we are processing the last byte
                if (byte_index == 4'd15) begin
                    next_state = DONE;
                    // Compute the result
                    if (next_splitter_count == 0) 
                        next_result = next_letter_count;
                    else 
                        next_result = next_splitter_count + 1;
                end else begin
                    next_state = PROCESS;
                    next_byte_index = byte_index + 1;
                end
            end

            DONE: begin
                next_done = 1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule