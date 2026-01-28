module space_replacer(
    input clk,
    input rst_n,
    input start,
    input [127:0] text_in,
    input [3:0] len_in,
    output reg [127:0] text_out,
    output reg [3:0] len_out,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] PROCESS  = 3'd1;
    localparam [2:0] FLUSH    = 3'd2;
    localparam [2:0] TERMINATE = 3'd3;
    localparam [2:0] WRITE    = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] i;                  // Input index
    reg [3:0] out_ptr;            // Output pointer
    reg [3:0] space_count;        // Consecutive space counter
    reg [7:0] current_char;       // Current character being processed
    reg [7:0] out_buffer [0:15];  // Output buffer
    reg [3:0] cycle_count;        // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            out_ptr <= 4'd0;
            space_count <= 4'd0;
            current_char <= 8'd0;
            done <= 1'b0;
            len_out <= 4'd0;
            cycle_count <= 8'd0;
            // Initialize output buffer
            integer j;
            for (j = 0; j < 16; j = j + 1) begin
                out_buffer[j] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        i <= 4'd0;
                        out_ptr <= 4'd0;
                        space_count <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < len_in) begin
                        current_char <= text_in[(i * 8) +: 8];
                        if (current_char == 8'h20) begin
                            space_count <= space_count + 4'd1;
                            i <= i + 4'd1;
                            next_state <= PROCESS;
                        end else begin
                            next_state <= FLUSH;
                        end
                    end else begin
                        next_state <= TERMINATE;
                    end
                end

                FLUSH: begin
                    if (space_count > 0) begin
                        if (space_count == 4'd1) begin
                            out_buffer[out_ptr] <= 8'h5F;  // '_'
                            out_ptr <= out_ptr + 4'd1;
                        end else if (space_count == 4'd2) begin
                            out_buffer[out_ptr] <= 8'h5F;  // '_'
                            out_ptr <= out_ptr + 4'd1;
                            out_buffer[out_ptr] <= 8'h5F;  // '_'
                            out_ptr <= out_ptr + 4'd1;
                        end else if (space_count >= 4'd3) begin
                            out_buffer[out_ptr] <= 8'h2D;  // '-'
                            out_ptr <= out_ptr + 4'd1;
                        end
                        space_count <= 4'd0;
                    end
                    // Write current character
                    out_buffer[out_ptr] <= current_char;
                    out_ptr <= out_ptr + 4'd1;
                    i <= i + 4'd1;
                    next_state <= PROCESS;
                end

                TERMINATE: begin
                    if (space_count > 0) begin
                        if (space_count == 4'd1) begin
                            out_buffer[out_ptr] <= 8'h5F;  // '_'
                            out_ptr <= out_ptr + 4'd1;
                        end else if (space_count == 4'd2) begin
                            out_buffer[out_ptr] <= 8'h5F;  // '_'
                            out_ptr <= out_ptr + 4'd1;
                            out_buffer[out_ptr] <= 8'h5F;  // '_'
                            out_ptr <= out_ptr + 4'd1;
                        end else if (space_count >= 4'd3) begin
                            out_buffer[out_ptr] <= 8'h2D;  // '-'
                            out_ptr <= out_ptr + 4'd1;
                        end
                        space_count <= 4'd0;
                    end
                    next_state <= WRITE;
                end

                WRITE: begin
                    // Copy output buffer to text_out
                    integer k;
                    for (k = 0; k < 16; k = k + 1) begin
                        text_out[(k * 8) +: 8] <= out_buffer[k];
                    end
                    len_out <= out_ptr;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule