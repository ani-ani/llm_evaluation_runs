module parse_music (
    input clk,
    input rst_n,
    input start,
    input [127:0] music_string,
    input [4:0] length,
    output reg [3:0] result,
    output reg result_valid,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [4:0] index; // Current index (0-15)
    reg [3:0] next_index_delta; // How much to increment index by
    wire [7:0] current_byte;
    wire [7:0] next_byte; // Byte at index + 1
    wire valid_range;
    wire valid_range_plus_1;

    // Extract bytes using bit slicing
    // music_string is 128 bits. Byte 0 is bits [7:0], Byte i is [8*i+7 : 8*i]
    // We can slice dynamically based on index
    assign current_byte = music_string[8*index +: 8];
    assign next_byte = music_string[8*(index + 1) +: 8];

    // Check if indices are within the valid length
    assign valid_range = (index < length);
    assign valid_range_plus_1 = ((index + 1) < length);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'b0;
            result_valid <= 1'b0;
            done <= 1'b0;
            index <= 5'b0;
        end else begin
            // Default outputs
            result_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 5'b0;
                    if (start) begin
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    if (valid_range) begin
                        // Check for two-byte tokens first if possible
                        if (valid_range_plus_1) begin
                            if (current_byte == 8'h6F && next_byte == 8'h7C) begin // 'o|'
                                result <= 4'd2; // 2 beats
                                result_valid <= 1'b1;
                                index <= index + 2;
                            end else if (current_byte == 8'h2E && next_byte == 8'h7C) begin // '.|'
                                result <= 4'd1; // 1 beat
                                result_valid <= 1'b1;
                                index <= index + 2;
                            end else if (current_byte == 8'h6F) begin // 'o'
                                result <= 4'd4; // 4 beats
                                result_valid <= 1'b1;
                                index <= index + 1;
                            end else if (current_byte == 8'h20) begin // Space
                                index <= index + 1;
                            end else begin
                                // Invalid character handling: skip or error
                                // Assuming requirement says spaces are skipped, others might be invalid
                                // Let's advance index to avoid infinite loop
                                index <= index + 1;
                            end
                        end else begin // Only 1 byte left (or single byte token case)
                            if (current_byte == 8'h6F) begin // 'o'
                                result <= 4'd4;
                                result_valid <= 1'b1;
                                index <= index + 1;
                            end else if (current_byte == 8'h20) begin // Space
                                index <= index + 1;
                            end else begin
                                index <= index + 1; // Advance on unknown
                            end
                        end
                    end else begin
                        // index >= length, parsing complete
                        state <= DONE;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1; // Keep high or pulse? Requirement: "assert done high". 
                    // Usually done stays high until reset or start. 
                    // To restart, start signal will transition from IDLE (which handles start), 
                    // but if we stay in DONE, we need to go to IDLE on start or wait for reset.
                    // Standard FSM behavior: Wait for reset or explicit transition.
                    // The IDLE state logic checks 'start', but we are in DONE.
                    // Let's add logic to return to IDLE when start is asserted, or stick to reset.
                    if (start) state <= PROCESSING; // Restart capability if needed, or go to IDLE first.
                    // Actually, typically done stays high until reset. Let's keep it simple: stay here.
                    // The IDLE check for start won't be hit if we are stuck here.
                    // Let's modify: if start is asserted in DONE, reset state.
                    if (start) begin
                        done <= 1'b0;
                        index <= 5'b0;
                        state <= PROCESSING; // Restart immediately
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
