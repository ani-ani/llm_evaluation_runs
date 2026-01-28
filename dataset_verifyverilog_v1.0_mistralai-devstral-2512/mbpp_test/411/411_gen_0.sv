module snake_to_camel(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_in [0:15],
    input wire [3:0] len_in,
    output reg [7:0] str_out [0:15],
    output reg [3:0] len_out,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] FETCH     = 3'd1;
    localparam [2:0] PROCESS   = 3'd2;
    localparam [2:0] CAPITALIZE = 3'd3;
    localparam [2:0] WRITE     = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] in_idx;
    reg [3:0] out_idx;
    reg [7:0] current_char;
    reg [7:0] next_char;
    reg prev_underscore;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            in_idx <= 4'd0;
            out_idx <= 4'd0;
            current_char <= 8'd0;
            next_char <= 8'd0;
            prev_underscore <= 1'b0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            len_out <= 4'd0;
            
            // Initialize output array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                str_out[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= FETCH;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FETCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (in_idx < len_in) begin
                        current_char <= str_in[in_idx];
                        if (in_idx + 4'd1 < len_in) begin
                            next_char <= str_in[in_idx + 4'd1];
                        end else begin
                            next_char <= 8'd0;
                        end
                        next_state <= PROCESS;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_char == 8'h5F) begin
                        prev_underscore <= 1'b1;
                        next_state <= FETCH;
                        in_idx <= in_idx + 4'd1;
                    end else begin
                        if (prev_underscore || in_idx == 4'd0) begin
                            next_state <= CAPITALIZE;
                        end else begin
                            next_state <= WRITE;
                        end
                    end
                end

                CAPITALIZE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_char >= 8'h61 && current_char <= 8'h7A) begin
                        current_char <= current_char - 8'd32;
                    end
                    next_state <= WRITE;
                end

                WRITE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (out_idx < 4'd16) begin
                        str_out[out_idx] <= current_char;
                        out_idx <= out_idx + 4'd1;
                        len_out <= out_idx;
                    end
                    prev_underscore <= 1'b0;
                    in_idx <= in_idx + 4'd1;
                    next_state <= FETCH;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule