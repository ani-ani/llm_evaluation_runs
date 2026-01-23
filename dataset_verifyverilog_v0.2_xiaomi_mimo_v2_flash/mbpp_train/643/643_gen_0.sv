module text_match_z_middle(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] char_index,
    input char_valid,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] count, next_count;
    reg found_z, next_found_z;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 3'b0;
            found_z <= 1'b0;
        end else begin
            state <= next_state;
            count <= next_count;
            found_z <= next_found_z;
        end
    end

    // Next state and output logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_count = count;
        next_found_z = found_z;
        result = 1'b0;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    next_count = 3'b0;
                    next_found_z = 1'b0;
                end
            end

            PROCESSING: begin
                if (char_valid) begin
                    // Check for 'z' (0x7A) at positions 1-6
                    if (char_in == 8'h7A) begin
                        if (char_index != 3'b000 && char_index != 3'b111) begin
                            next_found_z = 1'b1;
                        end
                    end

                    if (char_index == 3'b111) begin // Last character (index 7)
                        next_state = DONE;
                    end
                end
            end

            DONE: begin
                result = found_z;
                done = 1'b1;
                
                // Wait for start to reset to IDLE, or handle new request
                if (start) begin
                    next_state = PROCESSING;
                    next_count = 3'b0;
                    next_found_z = 1'b0;
                end else begin
                    next_state = IDLE; // Return to IDLE after DONE is sampled
                end
            end
        endcase
    end

endmodule