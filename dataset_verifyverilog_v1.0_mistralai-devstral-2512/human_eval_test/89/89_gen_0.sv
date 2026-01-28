module string_encrypt(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input char_done,
    output reg [7:0] char_out,
    output reg char_valid_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] READING   = 2'd1;
    localparam [1:0] PROCESSING = 2'd2;
    localparam [1:0] OUTPUT    = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] char_index;
    reg [3:0] read_count;
    reg [3:0] write_count;
    reg [7:0] char_buffer [0:15];
    reg [5:0] char_val;
    reg [5:0] shifted_val;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_index <= 4'd0;
            read_count <= 4'd0;
            write_count <= 4'd0;
            char_valid_out <= 1'b0;
            done <= 1'b0;
            char_out <= 8'd0;
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
                if (char_index == read_count) begin
                    next_state = OUTPUT;
                end
            end
            OUTPUT: begin
                if (write_count == read_count) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Character processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_index <= 4'd0;
            read_count <= 4'd0;
            write_count <= 4'd0;
        end else begin
            case (state)
                READING: begin
                    if (char_valid) begin
                        char_buffer[char_index] <= char_in;
                        char_index <= char_index + 4'd1;
                    end
                    if (char_done) begin
                        read_count <= char_index;
                    end
                end
                PROCESSING: begin
                    if (char_index < read_count) begin
                        char_val <= char_buffer[char_index] - 8'd97;
                        shifted_val <= (char_val + 4'd4) % 6'd26;
                        char_out <= shifted_val + 8'd97;
                        char_index <= char_index + 4'd1;
                    end
                end
                OUTPUT: begin
                    if (write_count < read_count) begin
                        char_valid_out <= 1'b1;
                        write_count <= write_count + 4'd1;
                    end else begin
                        char_valid_out <= 1'b0;
                        done <= 1'b1;
                    end
                end
                default: begin
                    char_valid_out <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule