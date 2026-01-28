module RemoveParentheses (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] input_string,
    input wire [3:0] input_len,
    output reg [63:0] output_string,
    output reg [3:0] output_len,
    output reg done
);

    // State machine definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN = 3'd1;
    localparam [2:0] WRITE = 3'd2;
    localparam [2:0] DONE = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] scan_index;
    reg [3:0] write_index;
    reg [3:0] depth;
    reg [63:0] filtered_string;
    reg [3:0] filtered_len;
    reg [7:0] current_char;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Character constants
    localparam [7:0] OPEN_PAREN = 8'h28;
    localparam [7:0] CLOSE_PAREN = 8'h29;

    // Current character extraction (little-endian: char0 at [7:0], char7 at [63:56])
    always @(*) begin
        case (scan_index)
            4'd0: current_char = input_string[7:0];
            4'd1: current_char = input_string[15:8];
            4'd2: current_char = input_string[23:16];
            4'd3: current_char = input_string[31:24];
            4'd4: current_char = input_string[39:32];
            4'd5: current_char = input_string[47:40];
            4'd6: current_char = input_string[55:48];
            4'd7: current_char = input_string[63:56];
            default: current_char = 8'h00;
        endcase
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SCAN;
                else
                    next_state = IDLE;
            end
            SCAN: begin
                if (scan_index >= input_len)
                    next_state = WRITE;
                else
                    next_state = SCAN;
            end
            WRITE: next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            scan_index <= 4'd0;
            write_index <= 4'd0;
            depth <= 4'd0;
            filtered_string <= 64'd0;
            filtered_len <= 4'd0;
            output_string <= 64'd0;
            output_len <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    scan_index <= 4'd0;
                    write_index <= 4'd0;
                    depth <= 4'd0;
                    filtered_string <= 64'd0;
                    filtered_len <= 4'd0;
                    output_string <= 64'd0;
                    output_len <= 4'd0;
                    cycle_count <= 8'd0;
                end

                SCAN: begin
                    if (scan_index < input_len && cycle_count < MAX_CYCLES) begin
                        // Check character type
                        if (current_char == OPEN_PAREN) begin
                            depth <= depth + 4'd1;
                        end else if (current_char == CLOSE_PAREN) begin
                            if (depth > 4'd0)
                                depth <= depth - 4'd1;
                        end else if (depth == 4'd0) begin
                            // Only output if outside parentheses
                            if (write_index < 4'd8) begin
                                // Pack into filtered_string (little-endian)
                                case (write_index)
                                    4'd0: filtered_string[7:0] <= current_char;
                                    4'd1: filtered_string[15:8] <= current_char;
                                    4'd2: filtered_string[23:16] <= current_char;
                                    4'd3: filtered_string[31:24] <= current_char;
                                    4'd4: filtered_string[39:32] <= current_char;
                                    4'd5: filtered_string[47:40] <= current_char;
                                    4'd6: filtered_string[55:48] <= current_char;
                                    4'd7: filtered_string[63:56] <= current_char;
                                endcase
                                write_index <= write_index + 4'd1;
                                filtered_len <= filtered_len + 4'd1;
                            end
                        end
                        scan_index <= scan_index + 4'd1;
                    end
                end

                WRITE: begin
                    output_string <= filtered_string;
                    output_len <= filtered_len;
                end

                DONE: begin
                    done <= 1'b1;
                    scan_index <= 4'd0;
                    write_index <= 4'd0;
                    depth <= 4'd0;
                    filtered_len <= 4'd0;
                    cycle_count <= 8'd0;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule