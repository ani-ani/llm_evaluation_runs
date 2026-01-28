module is_bored(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [5:0] char_index,
    input valid,
    output reg [3:0] result,
    output reg done,
    output reg [5:0] read_index
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] WAIT_READ = 2'd1;
    localparam [1:0] PROCESS_CHAR = 2'd2;
    localparam [1:0] DONE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [5:0] char_idx;
    reg [3:0] count;
    reg sentence_start;
    reg [7:0] current_char;

    // Delimiter detection
    wire is_delimiter = (char_in == 8'd46) || (char_in == 8'd63) || (char_in == 8'd33);
    wire is_upper_i = (char_in == 8'd73);

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            read_index <= 6'd0;
            char_idx <= 6'd0;
            count <= 4'd0;
            sentence_start <= 1'b1;
            current_char <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        char_idx <= 6'd0;
                        count <= 4'd0;
                        sentence_start <= 1'b1;
                        read_index <= 6'd0;
                        next_state <= WAIT_READ;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                WAIT_READ: begin
                    if (valid) begin
                        current_char <= char_in;
                        next_state <= PROCESS_CHAR;
                    end else begin
                        next_state <= WAIT_READ;
                    end
                end

                PROCESS_CHAR: begin
                    // Check if current character is 'I' at sentence start
                    if (sentence_start && is_upper_i) begin
                        count <= count + 4'd1;
                    end

                    // Update sentence start flag
                    if (is_delimiter) begin
                        sentence_start <= 1'b1;
                    end else begin
                        sentence_start <= 1'b0;
                    end

                    // Move to next character
                    if (char_idx == 6'd63 || char_in == 8'd0) begin
                        result <= count;
                        next_state <= DONE;
                    end else begin
                        char_idx <= char_idx + 6'd1;
                        read_index <= char_idx;
                        next_state <= WAIT_READ;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule