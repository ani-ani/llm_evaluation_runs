module happy_string_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input char_done,
    output reg happy,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] READING    = 2'd1;
    localparam [1:0] PROCESSING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;

    // Character window registers
    reg [7:0] window_0, window_1, window_2;

    // Character counter (0-16)
    reg [4:0] char_count;

    // Duplicate detection flags
    reg duplicate_found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            window_0 <= 8'd0;
            window_1 <= 8'd0;
            window_2 <= 8'd0;
            char_count <= 5'd0;
            duplicate_found <= 1'b0;
            happy <= 1'b0;
            done <= 1'b0;
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
                    next_state = READING;
                end
            end

            READING: begin
                if (char_done) begin
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Character processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            window_0 <= 8'd0;
            window_1 <= 8'd0;
            window_2 <= 8'd0;
            char_count <= 5'd0;
            duplicate_found <= 1'b0;
        end else begin
            case (state)
                READING: begin
                    if (char_valid) begin
                        // Shift window
                        window_0 <= window_1;
                        window_1 <= window_2;
                        window_2 <= char_in;
                        char_count <= char_count + 5'd1;

                        // Check for duplicates in current window
                        if (char_count >= 5'd3) begin
                            if ((window_0 == window_1) || 
                                (window_1 == window_2) || 
                                (window_0 == window_2)) begin
                                duplicate_found <= 1'b1;
                            end
                        end
                    end
                end

                PROCESSING: begin
                    // Final determination
                    if (char_count < 5'd3) begin
                        happy <= 1'b0;  // Too short
                    end else begin
                        happy <= !duplicate_found;
                    end
                    done <= 1'b1;
                end

                DONE_STATE: begin
                    done <= 1'b0;  // Clear done signal
                end

                default: begin
                    window_0 <= 8'd0;
                    window_1 <= 8'd0;
                    window_2 <= 8'd0;
                    char_count <= 5'd0;
                    duplicate_found <= 1'b0;
                end
            endcase
        end
    end

endmodule