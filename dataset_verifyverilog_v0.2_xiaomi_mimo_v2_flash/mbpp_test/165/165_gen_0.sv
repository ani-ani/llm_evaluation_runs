module count_char_position (
    input clk,
    input rst_n,
    input start,
    input [63:0] str_data,
    output reg [2:0] count,
    output reg done
);

    // FSM States
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [2:0] pos;           // Position counter 0-7
    reg [2:0] next_count;    // Combinational next count value
    reg [7:0] char;          // Current character extracted
    reg [7:0] expected_upper;
    reg [7:0] expected_lower;
    wire match;

    // Combinational Logic
    always @(*) begin
        // Extract byte based on position (str_data is packed [63:0], MSB is index 0)
        // Index 0: str_data[63:56], Index 1: str_data[55:48], ..., Index 7: str_data[7:0]
        case (pos)
            3'd0: char = str_data[63:56];
            3'd1: char = str_data[55:48];
            3'd2: char = str_data[47:40];
            3'd3: char = str_data[39:32];
            3'd4: char = str_data[31:24];
            3'd5: char = str_data[23:16];
            3'd6: char = str_data[15:8];
            3'd7: char = str_data[7:0];
            default: char = 8'h00;
        endcase

        // Expected characters for current position
        // 'A' + pos (0x41 + pos)
        // 'a' + pos (0x61 + pos)
        expected_upper = 8'h41 + pos;
        expected_lower = 8'h61 + pos;

        // Match condition
        match = (char == expected_upper) || (char == expected_lower);

        // Next count logic
        if (state == PROCESSING) begin
            if (match)
                next_count = count + 1'b1;
            else
                next_count = count;
        end else begin
            next_count = 3'b000;
        end
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 3'b000;
            done <= 1'b0;
            pos <= 3'b000;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        count <= 3'b000;
                        pos <= 3'b000;
                    end
                end

                PROCESSING: begin
                    count <= next_count;
                    if (pos == 3'd7) begin
                        state <= DONE;
                        pos <= 3'b000; // Reset for next run
                    end else begin
                        pos <= pos + 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        // Restart logic if start is held high or re-asserted
                        state <= PROCESSING;
                        count <= 3'b000;
                        done <= 1'b0;
                        pos <= 3'b000;
                    end else begin
                        // Wait for reset or restart
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule