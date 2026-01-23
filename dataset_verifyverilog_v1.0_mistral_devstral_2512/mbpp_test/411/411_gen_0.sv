module snake_to_camel (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] char_index,
    input wire input_valid,
    output reg [7:0] char_out,
    output reg [3:0] out_index,
    output reg output_valid,
    output reg done
);

    // Parameters
    localparam [7:0] UNDERSCORE = 8'h5F;
    localparam [7:0] LOWER_A = 8'h61;
    localparam [7:0] LOWER_Z = 8'h7A;
    localparam [7:0] TO_UPPER = 8'h20;
    localparam [3:0] MAX_LEN = 4'd8;

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] input_buffer [0:7];
    reg [3:0] in_idx;
    reg [3:0] out_idx;
    reg [3:0] read_count;
    reg capitalize_next;
    reg [7:0] current_char;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = READ;
                else
                    next_state = IDLE;
            end

            READ: begin
                if (input_valid && read_count < MAX_LEN)
                    next_state = PROCESS;
                else if (read_count >= MAX_LEN)
                    next_state = DONE_STATE;
                else
                    next_state = READ;
            end

            PROCESS: begin
                next_state = OUTPUT;
            end

            OUTPUT: begin
                if (out_idx < MAX_LEN)
                    next_state = READ;
                else
                    next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_out <= 8'd0;
            out_index <= 4'd0;
            output_valid <= 1'b0;
            done <= 1'b0;
            in_idx <= 4'd0;
            out_idx <= 4'd0;
            read_count <= 4'd0;
            capitalize_next <= 1'b1;
            current_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    output_valid <= 1'b0;
                    done <= 1'b0;
                    in_idx <= 4'd0;
                    out_idx <= 4'd0;
                    read_count <= 4'd0;
                    capitalize_next <= 1'b1;
                end

                READ: begin
                    if (input_valid && read_count < MAX_LEN) begin
                        input_buffer[in_idx] <= char_in;
                        current_char <= char_in;
                        in_idx <= in_idx + 1'b1;
                        read_count <= read_count + 1'b1;
                    end
                end

                PROCESS: begin
                    if (capitalize_next && current_char >= LOWER_A && current_char <= LOWER_Z) begin
                        char_out <= current_char - TO_UPPER;
                    end else begin
                        char_out <= current_char;
                    end

                    if (current_char == UNDERSCORE) begin
                        capitalize_next <= 1'b1;
                    end else begin
                        capitalize_next <= 1'b0;
                    end
                end

                OUTPUT: begin
                    output_valid <= 1'b1;
                    out_index <= out_idx;
                    out_idx <= out_idx + 1'b1;
                end

                DONE_STATE: begin
                    output_valid <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule