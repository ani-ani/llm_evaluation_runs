module count_upper(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] length,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] READING   = 2'd1;
    localparam [1:0] PROCESSING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            index <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                index <= 4'd0;
                cycle_count <= 4'd0;
                if (start) begin
                    next_state = READING;
                end
            end

            READING: begin
                next_state = PROCESSING;
            end

            PROCESSING: begin
                // Check if character is uppercase vowel at even index
                if ((index % 2 == 0) && 
                    (char_in == 8'd65 || char_in == 8'd69 || 
                     char_in == 8'd73 || char_in == 8'd79 || 
                     char_in == 8'd85)) begin
                    result <= result + 4'd1;
                end

                // Increment index and cycle count
                index <= index + 4'd1;
                cycle_count <= cycle_count + 4'd1;

                // Check if we've processed all characters
                if (index == length || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule