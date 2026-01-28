module string_concat(
    input clk,
    input rst_n,
    input start,
    input [7:0] str0 [0:7],
    input [7:0] str1 [0:7],
    input [7:0] str2 [0:7],
    input [7:0] str3 [0:7],
    input [1:0] count,
    output reg [7:0] result [0:31],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state, next_state;
    reg [5:0] byte_counter;  // 0 to 31 (32 bytes)
    reg [1:0] current_string;  // 0 to 3 (4 strings)
    reg [2:0] string_byte;  // 0 to 7 (8 bytes per string)

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            byte_counter <= 6'd0;
            current_string <= 2'd0;
            string_byte <= 3'd0;
            // Initialize result array
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end

            PROCESSING: begin
                if (byte_counter == 6'd31) begin
                    next_state = DONE;
                end else begin
                    next_state = PROCESSING;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in reset block
        end else if (state == PROCESSING) begin
            // Determine current string and byte position
            current_string = byte_counter[5:4];  // Upper 2 bits: 0-3
            string_byte = byte_counter[3:0];    // Lower 3 bits: 0-7

            // Copy byte from appropriate string
            case (current_string)
                2'd0: begin
                    if (count >= 2'd1) begin
                        result[byte_counter] <= str0[string_byte];
                    end else begin
                        result[byte_counter] <= 8'd0;
                    end
                end
                2'd1: begin
                    if (count >= 2'd2) begin
                        result[byte_counter] <= str1[string_byte];
                    end else begin
                        result[byte_counter] <= 8'd0;
                    end
                end
                2'd2: begin
                    if (count >= 2'd3) begin
                        result[byte_counter] <= str2[string_byte];
                    end else begin
                        result[byte_counter] <= 8'd0;
                    end
                end
                2'd3: begin
                    if (count == 2'd3) begin
                        result[byte_counter] <= str3[string_byte];
                    end else begin
                        result[byte_counter] <= 8'd0;
                    end
                end
                default: result[byte_counter] <= 8'd0;
            endcase

            // Increment counter
            byte_counter <= byte_counter + 6'd1;
        end else if (state == DONE) begin
            done <= 1'b1;
        end
    end

endmodule