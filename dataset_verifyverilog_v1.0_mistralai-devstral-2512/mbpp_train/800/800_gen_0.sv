module RemoveWhitespace(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_str [0:15],
    input wire [3:0] valid_len,
    output reg [7:0] output_str [0:15],
    output reg [3:0] output_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] read_idx;
    reg [3:0] write_idx;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Internal buffer for processing
    reg [7:0] internal_buffer [0:15];

    // Whitespace detection
    wire is_whitespace;
    assign is_whitespace = (internal_buffer[read_idx] == 8'h20) ||
                          (internal_buffer[read_idx] == 8'h09) ||
                          (internal_buffer[read_idx] == 8'h0A) ||
                          (internal_buffer[read_idx] == 8'h0D);

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (read_idx == valid_len || cycle_count >= MAX_CYCLES)
                    next_state = DONE_STATE;
                else
                    next_state = PROCESSING;
            end
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State register with reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            read_idx <= 4'd0;
            write_idx <= 4'd0;
            output_len <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize output buffer
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                output_str[i] <= 8'd0;
                internal_buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Copy input to internal buffer
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            internal_buffer[i] <= input_str[i];
                        end
                        read_idx <= 4'd0;
                        write_idx <= 4'd0;
                    end
                end
                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (!is_whitespace) begin
                        output_str[write_idx] <= internal_buffer[read_idx];
                        write_idx <= write_idx + 4'd1;
                    end
                    read_idx <= read_idx + 4'd1;
                    
                    // Check if processing is complete
                    if (read_idx == valid_len) begin
                        output_len <= write_idx;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule