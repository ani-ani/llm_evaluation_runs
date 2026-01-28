module whitespace_remover(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_str [0:15],
    input wire [3:0] length,
    output reg [7:0] output_str [0:15],
    output reg [3:0] output_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READ_INPUT = 2'd1;
    localparam [1:0] WRITE_OUTPUT = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] read_index;
    reg [3:0] write_index;
    reg [7:0] temp_buffer [0:15];
    reg [3:0] non_ws_count;
    reg [7:0] current_byte;
    reg is_whitespace;

    // Whitespace detection
    always @(*) begin
        is_whitespace = (current_byte == 8'h20) ||
                        (current_byte == 8'h09) ||
                        (current_byte == 8'h0A) ||
                        (current_byte == 8'h0D);
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            read_index <= 4'd0;
            write_index <= 4'd0;
            non_ws_count <= 4'd0;
            done <= 1'b0;
            output_len <= 4'd0;
            
            // Initialize output_str to all zeros
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                output_str[i] <= 8'd0;
            end
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
                    next_state = READ_INPUT;
                    read_index = 4'd0;
                    write_index = 4'd0;
                    non_ws_count = 4'd0;
                end
            end
            
            READ_INPUT: begin
                if (read_index < length) begin
                    current_byte = input_str[read_index];
                    if (!is_whitespace) begin
                        temp_buffer[write_index] = current_byte;
                        write_index = write_index + 4'd1;
                        non_ws_count = non_ws_count + 4'd1;
                    end
                    read_index = read_index + 4'd1;
                end else begin
                    next_state = WRITE_OUTPUT;
                end
            end
            
            WRITE_OUTPUT: begin
                if (write_index < 16) begin
                    output_str[write_index] = temp_buffer[write_index];
                    write_index = write_index + 4'd1;
                end else begin
                    next_state = COMPLETE;
                end
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            output_len <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                
                READ_INPUT: begin
                    done <= 1'b0;
                end
                
                WRITE_OUTPUT: begin
                    done <= 1'b0;
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    output_len <= non_ws_count;
                end
                
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule